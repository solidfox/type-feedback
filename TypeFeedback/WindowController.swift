//
//  WindowController.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2017-03-11.
//  Copyright © 2017 Daniel Schlaug. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController, NSWindowDelegate {
	@IBAction func onSpellingSegmentedControlChange(_ sender: NSSegmentedControl) {
		NSUserDefaultsController.shared.defaults.set(sender.selectedSegment, forKey: AppDefaults.keys.spellingMode.rawValue)
		NotificationCenter.default.post(Notification(name: .spellingModeUpdated))
	}
	@IBOutlet weak var spellingSegmentedControl: NSSegmentedControl!
	
	/// The text side of the window. The window's content is a split view with the documents sidebar beside it.
	private(set) var textViewController: ViewController?
	private(set) var splitViewController: DocumentSplitViewController?

    override func windowDidLoad() {
        super.windowDidLoad()
		
		if let window = window {
			window.backgroundColor = Palette.paper
			window.delegate = self
			showDocumentsSidebar(in: window)
		}
		
		showSpellingMode()
		NotificationCenter.default.addObserver(self, selector: #selector(onSpellingModeUpdated(_:)), name: .spellingModeUpdated, object: nil)
    }

	/// Puts the text from the storyboard next to the documents sidebar.
	private func showDocumentsSidebar(in window: NSWindow) {
		guard let textViewController = contentViewController as? ViewController else { return }
		self.textViewController = textViewController
		let textSize = textViewController.view.frame.size
		let splitViewController = DocumentSplitViewController(textViewController: textViewController)
		self.splitViewController = splitViewController
		window.contentViewController = splitViewController
		let sidebarWidth = splitViewController.isSidebarVisible ? DocumentSplitViewController.sidebarWidth : 0
		window.setContentSize(NSSize(width: textSize.width + sidebarWidth, height: max(textSize.height, 468)))
	}
	
	/// AppKit calls this whenever the document's file name changes, also when the file is renamed or moved elsewhere.
	override func synchronizeWindowTitleWithDocumentName() {
		super.synchronizeWindowTitleWithDocumentName()
		splitViewController?.sidebarViewController.showCurrentDocument()
	}

	/// The setting is shared by all windows, so a change in one window updates the others.
	@objc func onSpellingModeUpdated(_ notification: Notification) {
		showSpellingMode()
	}
	
	func showSpellingMode() {
		spellingSegmentedControl.selectedSegment = (NSUserDefaultsController.shared.defaults.integer(forKey: AppDefaults.keys.spellingMode.rawValue))
	}
}

/// The toolbar's print button. Its "printer" image is an SF Symbol, which macOS before 11 does not have,
/// so older Macs get a printer drawn here instead of an empty button.
class PrintToolbarItem: NSToolbarItem {
	override func awakeFromNib() {
		super.awakeFromNib()
		if #available(macOS 11.0, *) { return }
		image = PrintToolbarItem.drawnPrinter
	}

	static let drawnPrinter: NSImage = {
		let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
			NSColor.black.set()
			// Printer body, with a slot cut out where the printed page comes out.
			NSBezierPath(roundedRect: NSRect(x: 1, y: 4.5, width: 16, height: 7), xRadius: 1.5, yRadius: 1.5).fill()
			NSRect(x: 4, y: 0, width: 10, height: 8).fill(using: .clear)
			// Paper going in at the top and coming out at the bottom.
			let paperIn = NSBezierPath(rect: NSRect(x: 5.5, y: 11.5, width: 7, height: 3.5))
			let paperOut = NSBezierPath(rect: NSRect(x: 5.5, y: 1.5, width: 7, height: 6))
			paperIn.lineWidth = 1
			paperOut.lineWidth = 1
			paperIn.stroke()
			paperOut.stroke()
			return true
		}
		image.isTemplate = true
		return image
	}()
}
