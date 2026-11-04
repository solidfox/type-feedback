//
//  DocumentLibrary.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

/// The folder where all texts live, Documents/TypeFeedback, and the list of texts in it, newest first.
/// One shared library watches the folder; every window's sidebar shows its list.
final class DocumentLibrary {

	static let shared = DocumentLibrary()

	/// Posted on the main queue whenever `items` may have changed.
	static let didChangeNotification = Notification.Name("DocumentLibraryDidChange")

	struct Item: Equatable {
		/// Where the text is, or will be once iCloud has downloaded it.
		let url: URL
		let name: String
		let modificationDate: Date
		/// False for a text that iCloud has kept in the cloud only (shown in the folder as a `.Name.txt.icloud` file).
		let isDownloaded: Bool
	}

	private(set) var items: [Item] = []

	let folderURL: URL = {
		#if DEBUG
		// Lets tests run against a scratch folder: -DocumentsFolderOverride /some/folder
		if let path = UserDefaults.standard.string(forKey: "DocumentsFolderOverride") {
			return URL(fileURLWithPath: path, isDirectory: true)
		}
		#endif
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
		return documents.appendingPathComponent("TypeFeedback", isDirectory: true)
	}()

	private var folderWatch: DispatchSourceFileSystemObject?
	private var pendingReload: DispatchWorkItem?
	private var isStarted = false

	/// Starts watching the folder. Safe to call more than once.
	func start() {
		guard !isStarted else { return }
		isStarted = true
		// Catches anything the folder watch can't see, such as a text edited in place by another app.
		NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
			self?.setNeedsReload()
		}
		reload()
	}

	/// Reloads the list shortly, folding bursts of changes (a save touches the folder several times) into one reload.
	func setNeedsReload() {
		pendingReload?.cancel()
		let reload = DispatchWorkItem { [weak self] in self?.reload() }
		pendingReload = reload
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: reload)
	}

	private func reload() {
		pendingReload = nil
		if folderWatch == nil {
			try? createFolder()
			watchFolder()
		}
		let newItems = scanFolder()
		if newItems != items {
			items = newItems
			NotificationCenter.default.post(name: DocumentLibrary.didChangeNotification, object: self)
		}
	}

	func createFolder() throws {
		try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
	}

	/// Watches the folder itself, so files added, removed or renamed there (also from Finder or iCloud) show up.
	/// Saving a document also counts, because NSDocument saves by replacing the file.
	private func watchFolder() {
		let descriptor = Darwin.open(folderURL.path, O_EVTONLY)
		guard descriptor >= 0 else { return }
		let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
		source.setEventHandler { [weak self, unowned source] in
			guard let self = self else { return }
			if !source.data.isDisjoint(with: [.delete, .rename]) {
				// The folder itself was moved or deleted; watch it again where it should be.
				source.cancel()
				self.folderWatch = nil
			}
			self.setNeedsReload()
		}
		source.setCancelHandler {
			Darwin.close(descriptor)
		}
		source.resume()
		folderWatch = source
	}

	private func scanFolder() -> [Item] {
		let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
		guard let urls = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: []) else {
			return []
		}
		var items: [Item] = []
		for url in urls {
			guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
			let date = values.contentModificationDate ?? .distantPast
			var fileName = url.lastPathComponent
			var isDownloaded = true
			if fileName.hasPrefix(".") {
				// Only hidden files that stand in for texts kept in iCloud: ".Name.txt.icloud".
				guard fileName.hasSuffix(".icloud") else { continue }
				fileName = String(fileName.dropFirst().dropLast(".icloud".count))
				isDownloaded = false
			}
			let textURL = folderURL.appendingPathComponent(fileName)
			guard textURL.pathExtension.lowercased() == "txt" else { continue }
			items.append(Item(url: textURL, name: textURL.deletingPathExtension().lastPathComponent, modificationDate: date, isDownloaded: isDownloaded))
		}
		return items.sorted { a, b in
			if a.modificationDate != b.modificationDate {
				return a.modificationDate > b.modificationDate
			}
			return a.name.localizedStandardCompare(b.name) == .orderedAscending
		}
	}

	/// File names handed out for saves and renames that haven't reached the disk yet. Saving or moving onto an existing
	/// file replaces it, so two texts named at the same moment must not get the same name. This guards against the app
	/// itself; another app creating the very same generated name in that moment is left out on purpose, because claiming
	/// names with empty placeholder files would flash them in the sidebar and sync them to iCloud.
	private var reservedNames = Set<String>()

	/// Reserves a file name in the folder that no other text uses: "Name.txt", "Name 2.txt", …
	/// Call `releaseURL` once the save or move into it has finished.
	func reserveUnusedURL(named name: String) -> URL {
		var number = 1
		while true {
			let fileName = number == 1 ? name : "\(name) \(number)"
			let url = folderURL.appendingPathComponent(fileName).appendingPathExtension("txt")
			let iCloudPlaceholder = folderURL.appendingPathComponent(".\(url.lastPathComponent).icloud")
			if !reservedNames.contains(reservationName(url)) && !FileManager.default.fileExists(atPath: url.path) && !FileManager.default.fileExists(atPath: iCloudPlaceholder.path) {
				reservedNames.insert(reservationName(url))
				return url
			}
			number += 1
		}
	}

	func releaseURL(_ url: URL) {
		reservedNames.remove(reservationName(url))
	}

	/// The Mac's disk normally treats "Hej.txt" and "hej.txt" (and the two ways of writing "å") as the same file.
	private func reservationName(_ url: URL) -> String {
		return url.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
	}

	/// True for a text saved in the TypeFeedback folder, as opposed to one opened from somewhere else.
	func contains(_ url: URL) -> Bool {
		return url.deletingLastPathComponent().standardizedFileURL == folderURL.standardizedFileURL && url.pathExtension.lowercased() == "txt"
	}

	/// Opens a text, or brings its window to the front if it is already open.
	func open(_ item: Item) {
		guard !item.isDownloaded else {
			NSDocumentController.shared.openDocument(withContentsOf: item.url, display: true) { _, _, error in
				if let error = error {
					NSApp.presentError(error)
				}
			}
			return
		}
		// A coordinated read waits until iCloud has downloaded the text, and tells where it is now.
		try? FileManager.default.startDownloadingUbiquitousItem(at: item.url)
		DispatchQueue.global(qos: .userInitiated).async {
			var coordinationError: NSError?
			var downloadedURL = item.url
			NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: item.url, options: [], error: &coordinationError) { url in
				downloadedURL = url
			}
			DispatchQueue.main.async {
				if let error = coordinationError {
					NSApp.presentError(error)
				} else {
					self.open(Item(url: downloadedURL, name: item.name, modificationDate: item.modificationDate, isDownloaded: true))
				}
			}
		}
	}

	/// Moves a text to the Trash. If it is open, it is saved and closed first.
	func moveToTrash(_ item: Item) {
		if let document = NSDocumentController.shared.document(for: item.url) {
			moveToTrash(document)
		} else {
			recycle(item.isDownloaded ? item.url : folderURL.appendingPathComponent(".\(item.url.lastPathComponent).icloud"))
		}
	}

	/// Saves and closes an open text, then moves its file, wherever it is by then, to the Trash, so the Trash holds the
	/// latest writing. If it is the only open text, a new empty one opens first, because closing the last window quits the app.
	func moveToTrash(_ document: NSDocument) {
		let controller = NSDocumentController.shared
		document.autosave(withImplicitCancellability: false) { error in
			if let error = error {
				// Keep the text open rather than lose what hasn't been saved.
				NSApp.presentError(error)
				return
			}
			guard let url = document.fileURL else { return }
			if controller.documents.count == 1 {
				controller.newDocument(nil)
			}
			document.close()
			self.recycle(url)
		}
	}

	private func recycle(_ url: URL) {
		NSWorkspace.shared.recycle([url]) { _, error in
			if let error = error {
				NSApp.presentError(error)
			}
			self.setNeedsReload()
		}
	}
}

/// How new texts are named. A new text is saved at once as "Text 2026-11-04 14.32". Once its first sentence is written
/// it is renamed, one time only, to the first words, e.g. "Min hund heter Bosse".
enum DocumentNaming {

	private static let maximumWords = 5
	private static let maximumLength = 40
	/// Without a full stop or a new line, wait for this many finished words, so the name isn't half a sentence.
	private static let wordsBeforeNaming = 6

	static func dateName(for date: Date = Date()) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd HH.mm"
		return "Text \(formatter.string(from: date))"
	}

	/// True for names given by `dateName`, also with a number added to make them unique ("Text 2026-11-04 14.32 2").
	static func isDateName(_ name: String) -> Bool {
		return name.range(of: "^Text [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\\.[0-9]{2}( [0-9]+)?$", options: .regularExpression) != nil
	}

	/// A name made of the text's first words, or nil while the first sentence is still being written.
	static func name(fromText text: String) -> String? {
		let sentenceEnds = CharacterSet(charactersIn: ".!?\n\r")
		let trimmedStart = text.drop { $0.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains) }
		let start = String(trimmedStart.prefix(500))
		let firstSentence: String
		let sentenceIsFinished: Bool
		if let end = start.rangeOfCharacter(from: sentenceEnds) {
			firstSentence = String(start[..<end.lowerBound])
			sentenceIsFinished = true
		} else {
			firstSentence = start
			sentenceIsFinished = false
		}
		var words = firstSentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
		if !sentenceIsFinished {
			// The last word may still be being typed, unless a space follows it.
			if let last = firstSentence.unicodeScalars.last, !CharacterSet.whitespaces.contains(last) {
				words = Array(words.dropLast())
			}
			guard words.count >= wordsBeforeNaming else { return nil }
		}
		var name = ""
		for word in words.prefix(maximumWords) {
			let candidate = name.isEmpty ? word : "\(name) \(word)"
			if candidate.count > maximumLength && !name.isEmpty { break }
			name = candidate
		}
		return cleanedFileName(name)
	}

	/// Removes what macOS doesn't allow or hides in file names, and punctuation left at the ends.
	private static func cleanedFileName(_ name: String) -> String? {
		var cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
		cleaned = String(cleaned.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.map(Character.init))
		cleaned = cleaned.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespaces))
		if cleaned.count > maximumLength {
			cleaned = String(cleaned.prefix(maximumLength)).trimmingCharacters(in: .whitespaces)
		}
		guard !cleaned.isEmpty, !cleaned.hasPrefix("."), cleaned.rangeOfCharacter(from: .alphanumerics) != nil else { return nil }
		return cleaned
	}
}
