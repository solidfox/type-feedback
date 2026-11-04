//
//  Document.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

class Document: NSDocument {

	static let textFont = font(size: 20)

	static func font(size: CGFloat) -> NSFont {
		return NSFont(name: "OpenDyslexic", size: size) ?? NSFont.systemFont(ofSize: size)
	}

	/// The document's text. Every window showing this document edits this storage directly.
	let textStorage = NSTextStorage()

	/// Set once a document has taken over the legacy text, so later new documents start empty.
	private static var legacyTextClaimed = false
	
	/// True while this document holds text taken over from user defaults that has not been saved yet.
	private var holdsLegacyText = false

	/// True while text is being loaded from a file rather than written.
	private var isReadingText = false
	/// True once someone has written in this document since it was opened.
	private var isWrittenInThisSession = false
	private var isFilingScheduled = false
	private var isRenaming = false
	private var automaticRenameFailed = false
	/// Completion handlers waiting for the save into the TypeFeedback folder; nil when no such save is running.
	private var librarySaveHandlers: [(Error?) -> Void]?

	override init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(documentTextDidChange(_:)), name: NSTextStorage.didProcessEditingNotification, object: textStorage)
	}
	
	/// A new untitled document. Versions before the document-based app kept a single text in user defaults;
	/// the first new document takes it over. Once that document is saved the text is marked as migrated, but kept
	/// in user defaults as a backup, because an untitled document can still be deleted from the close dialog.
	convenience init(type typeName: String) throws {
		self.init()
		fileType = typeName
		let defaults = NSUserDefaultsController.shared.defaults
		if !Document.legacyTextClaimed, !defaults.bool(forKey: AppDefaults.keys.legacyTextMigrated.rawValue), let legacyText = defaults.string(forKey: AppDefaults.keys.textViewContents.rawValue), !legacyText.isEmpty {
			Document.legacyTextClaimed = true
			setText(legacyText)
			updateChangeCount(.changeDone)
			holdsLegacyText = true
		}
	}
	
	override class var autosavesInPlace: Bool {
		return true
	}

	override func makeWindowControllers() {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! WindowController
		addWindowController(windowController)
		windowController.textViewController?.representedObject = self
	}

	override func data(ofType typeName: String) throws -> Data {
		return Data(textStorage.string.utf8)
	}

	override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
		// A text view merges ongoing typing into one undo step. Typing that continues after a save or autosave would
		// then never reach the undo manager, so the document would not count it as a change: no "Edited", no
		// autosave, and the text lost on quit. Start a new undo step for whatever is typed next.
		for case let windowController as WindowController in windowControllers {
			windowController.textViewController?.textView?.breakUndoCoalescing()
		}
		super.save(to: url, ofType: typeName, for: saveOperation) { error in
			if error == nil && self.holdsLegacyText {
				NSUserDefaultsController.shared.defaults.set(true, forKey: AppDefaults.keys.legacyTextMigrated.rawValue)
				self.holdsLegacyText = false
			}
			DocumentLibrary.shared.setNeedsReload()
			completionHandler(error)
		}
	}

	// MARK: Saving new texts without asking

	/// New texts are saved straight into the TypeFeedback folder, so nobody meets a Save dialog and a new text can't be
	/// thrown away from the close or quit dialog. Autosave normally keeps untitled documents elsewhere; save them there instead.
	override func autosave(withImplicitCancellability autosavingIsImplicitlyCancellable: Bool, completionHandler: @escaping (Error?) -> Void) {
		if needsSavingToLibrary {
			saveToLibrary(completionHandler: completionHandler)
		} else {
			super.autosave(withImplicitCancellability: autosavingIsImplicitlyCancellable, completionHandler: completionHandler)
		}
	}

	/// File › Save on a new text saves it into the folder instead of asking where.
	override func save(_ sender: Any?) {
		if fileURL == nil && !isInViewingMode {
			saveToLibrary { error in
				if let error = error {
					self.presentError(error)
				}
			}
		} else {
			super.save(sender)
		}
	}

	/// Closing or quitting saves a new text first, so AppKit never asks whether to keep or delete it.
	override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
		if fileURL == nil && !isInViewingMode {
			if textStorage.length == 0 {
				// Nothing was written, so there is nothing to keep.
				updateChangeCount(.changeCleared)
			} else {
				saveToLibrary { _ in
					// If saving failed, AppKit's own dialog still lets the text be saved somewhere else.
					super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
				}
				return
			}
		}
		super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
	}

	private var needsSavingToLibrary: Bool {
		return fileURL == nil && textStorage.length > 0 && !isInViewingMode
	}

	/// Saves a new text into the TypeFeedback folder, named after its first words if they are written already, otherwise by date.
	private func saveToLibrary(completionHandler: @escaping (Error?) -> Void) {
		if librarySaveHandlers != nil {
			librarySaveHandlers?.append(completionHandler)
			return
		}
		librarySaveHandlers = [completionHandler]
		let finish = { (error: Error?) in
			let handlers = self.librarySaveHandlers ?? []
			self.librarySaveHandlers = nil
			handlers.forEach { $0(error) }
		}
		let library = DocumentLibrary.shared
		do {
			try library.createFolder()
		} catch {
			finish(error)
			return
		}
		let name = DocumentNaming.name(fromText: textStorage.string) ?? DocumentNaming.dateName()
		let url = library.reserveUnusedURL(named: name)
		save(to: url, ofType: fileType ?? "public.plain-text", for: .saveAsOperation) { error in
			library.releaseURL(url)
			finish(error)
		}
	}

	@objc private func documentTextDidChange(_ notification: Notification) {
		guard !isReadingText, textStorage.editedMask.contains(.editedCharacters) else { return }
		isWrittenInThisSession = true
		if !isFilingScheduled {
			isFilingScheduled = true
			// A moment later, so the edit has been counted as a change and a burst of typing is handled once.
			perform(#selector(fileTextAutomatically), with: nil, afterDelay: 1)
		}
	}

	/// Saves a new text into the folder as soon as something is written in it, and gives a date-named text its
	/// real name once its first sentence is written. That rename happens once; after that the name stays.
	@objc private func fileTextAutomatically() {
		isFilingScheduled = false
		if fileURL == nil {
			if needsSavingToLibrary && isDocumentEdited {
				saveToLibrary { _ in }
			}
		} else {
			renameAutomaticallyIfNeeded()
		}
	}

	private func renameAutomaticallyIfNeeded() {
		guard isWrittenInThisSession, !isRenaming, !automaticRenameFailed, !isInViewingMode, let url = fileURL,
			DocumentNaming.isDateName(url.deletingPathExtension().lastPathComponent),
			let name = DocumentNaming.name(fromText: textStorage.string) else { return }
		isRenaming = true
		let newURL = DocumentLibrary.shared.reserveUnusedURL(named: name, in: url.deletingLastPathComponent())
		move(to: newURL) { error in
			DocumentLibrary.shared.releaseURL(newURL)
			self.isRenaming = false
			self.automaticRenameFailed = error != nil
			DocumentLibrary.shared.setNeedsReload()
		}
	}
	
	override func read(from data: Data, ofType typeName: String) throws {
		let text: String?
		if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
			text = String(data: data, encoding: .utf32)
		} else if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
			text = String(data: data, encoding: .utf16)
		} else if !data.contains(0) {
			text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252)
		} else {
			// Probably UTF-16 without a byte order mark; refuse rather than guess and save it back garbled.
			text = nil
		}
		guard let decodedText = text else {
			throw CocoaError(.fileReadInapplicableStringEncoding)
		}
		isReadingText = true
		setText(decodedText)
		isReadingText = false
	}

	func setText(_ text: String) {
		let attributes: [NSAttributedString.Key: Any] = [.font: Document.textFont, .foregroundColor: NSColor.textColor]
		textStorage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
	}

}
