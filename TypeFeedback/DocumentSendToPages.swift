//
//  DocumentSendToPages.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-05.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa
// kASAppleScriptSuite and the other AppleScript handler constants
import Carbon

/// File › Skicka till Pages and the toolbar button: a new Pages document with a copy of the text, to format and hand in.
/// Pages makes the document itself (AppleScript), so it is a normal untitled Pages document that saves where Pages
/// documents usually go. The TypeFeedback document is only read.
extension Document {

	@IBAction func sendToPages(_ sender: Any?) {
		guard let pages = PagesApp.find() else {
			showSendToPagesAlert(message: "Pages finns inte på den här datorn", information: "Be en vuxen att installera Pages från App Store. Din text finns kvar här i TypeFeedback.")
			return
		}
		PagesApp.shareTextFont()
		let font = Document.textFont.familyName == "OpenDyslexic" ? Document.textFont.fontName : nil
		do {
			try pages.makeDocument(text: textStorage.string, fontName: font, fontSize: 16)
		} catch PagesApp.Failure.notAllowed {
			showSendToPagesAlert(message: "TypeFeedback får inte öppna Pages", information: "Be en vuxen att slå på Pages för TypeFeedback i Systeminställningar › Integritet och säkerhet › Automatisering. Din text finns kvar här i TypeFeedback.", offersPrivacySettings: true)
		} catch {
			showSendToPagesAlert(message: "Det gick inte att skicka texten till Pages", information: "Försök igen om en stund. Din text finns kvar här i TypeFeedback.\n\n(\(error.localizedDescription))")
		}
	}

	/// There is nothing to send while the text is empty.
	override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		if item.action == #selector(sendToPages(_:)) {
			return !textStorage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
		return super.validateUserInterfaceItem(item)
	}

	private func showSendToPagesAlert(message: String, information: String, offersPrivacySettings: Bool = false) {
		let alert = NSAlert()
		alert.messageText = message
		alert.informativeText = information
		alert.addButton(withTitle: "OK")
		if offersPrivacySettings {
			alert.addButton(withTitle: "Öppna Systeminställningar")
		}
		let handler: (NSApplication.ModalResponse) -> Void = { response in
			if response == .alertSecondButtonReturn, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
				NSWorkspace.shared.open(url)
			}
		}
		if let window = windowForSheet {
			alert.beginSheetModal(for: window, completionHandler: handler)
		} else {
			handler(alert.runModal())
		}
	}

}

/// The installed Pages, driven through AppleScript.
struct PagesApp {

	enum Failure: Error {
		/// The user said no to TypeFeedback controlling Pages (macOS 10.14 and later ask once).
		case notAllowed
		case script(code: Int, message: String)
	}

	/// The free App Store Pages and the newer Pages from Apple Creator Studio. A Pages that is already open wins.
	static let bundleIdentifiers = ["com.apple.iWork.Pages", "com.apple.Pages"]

	let bundleIdentifier: String

	static func find() -> PagesApp? {
		let running = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
		let installed = bundleIdentifiers.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
		guard let bundleIdentifier = installed.first(where: running.contains) ?? installed.first else { return nil }
		return PagesApp(bundleIdentifier: bundleIdentifier)
	}

	/// OpenDyslexic comes inside TypeFeedback and only TypeFeedback can see it. Registering it for this login
	/// session lets Pages use it too, until the user logs out. If that fails, Pages keeps its own font.
	static func shareTextFont() {
		guard let url = Bundle.main.url(forResource: "OpenDyslexic-Regular", withExtension: "otf") else { return }
		// Fails harmlessly with "already registered" from the second time on.
		CTFontManagerRegisterFontsForURL(url as CFURL, .session, nil)
	}

	/// Asks Pages for a new document holding `text`. Blocks until Pages has made it, which takes a few seconds when
	/// Pages has to start, and waits for the user to answer macOS's question the first time.
	func makeDocument(text: String, fontName: String?, fontSize: CGFloat) throws {
		// The text goes in as a handler argument, never as part of the script source.
		let source = """
		on sendText(theText, fontName, fontSize)
			tell application id "\(bundleIdentifier)"
				set newDocument to make new document with properties {body text:theText}
				if fontName is not "" then
					try
						set font of body text of newDocument to fontName
					end try
				end if
				try
					set size of body text of newDocument to fontSize
				end try
				activate
			end tell
		end sendText
		"""
		guard let script = NSAppleScript(source: source) else {
			throw Failure.script(code: 0, message: "The script could not be made")
		}
		let arguments = NSAppleEventDescriptor.list()
		arguments.insert(NSAppleEventDescriptor(string: text), at: 1)
		arguments.insert(NSAppleEventDescriptor(string: fontName ?? ""), at: 2)
		arguments.insert(NSAppleEventDescriptor(int32: Int32(fontSize)), at: 3)

		let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite), eventID: AEEventID(kASSubroutineEvent), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
		event.setParam(NSAppleEventDescriptor(string: "sendtext"), forKeyword: AEKeyword(keyASSubroutineName))
		event.setParam(arguments, forKeyword: keyDirectObject)

		var errorInfo: NSDictionary?
		_ = script.executeAppleEvent(event, error: &errorInfo)
		if let errorInfo = errorInfo {
			let code = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
			let message = errorInfo[NSAppleScript.errorMessage] as? String ?? ""
			// -1743 is errAEEventNotPermitted: the user turned TypeFeedback off under Automation.
			if code == -1743 {
				throw Failure.notAllowed
			}
			throw Failure.script(code: code, message: message)
		}
	}

}

extension PagesApp.Failure: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .notAllowed:
			return "Not allowed to control Pages (-1743)"
		case let .script(code, message):
			return "\(message) (\(code))"
		}
	}
}
