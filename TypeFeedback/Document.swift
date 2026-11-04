//
//  Document.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

class Document: NSDocument {

	static let textFont = NSFont(name: "OpenDyslexic", size: 20) ?? NSFont.systemFont(ofSize: 20)

	/// The document's text. Every window showing this document edits this storage directly.
	let textStorage = NSTextStorage()

	/// Set once a document has taken over the legacy text, so later new documents start empty.
	private static var legacyTextClaimed = false
	
	/// True while this document holds text migrated from user defaults that has not been saved yet.
	private var holdsLegacyText = false
	
	/// A new untitled document. Versions before the document-based app kept a single text in user defaults;
	/// the first new document takes it over, and it is removed from user defaults once that document is saved.
	convenience init(type typeName: String) throws {
		self.init()
		fileType = typeName
		if !Document.legacyTextClaimed, let legacyText = NSUserDefaultsController.shared.defaults.string(forKey: AppDefaults.keys.textViewContents.rawValue), !legacyText.isEmpty {
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
		windowController.contentViewController?.representedObject = self
	}

	override func data(ofType typeName: String) throws -> Data {
		return textStorage.string.data(using: .utf8)!
	}

	override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
		super.save(to: url, ofType: typeName, for: saveOperation) { error in
			if error == nil && self.holdsLegacyText {
				NSUserDefaultsController.shared.defaults.removeObject(forKey: AppDefaults.keys.textViewContents.rawValue)
				self.holdsLegacyText = false
			}
			completionHandler(error)
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
		setText(decodedText)
	}

	func setText(_ text: String) {
		let attributes: [NSAttributedString.Key: Any] = [.font: Document.textFont, .foregroundColor: NSColor.textColor]
		textStorage.setAttributedString(NSAttributedString(string: text, attributes: attributes))
	}

}
