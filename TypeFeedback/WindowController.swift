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
    
    @IBAction func print(_ sender: Any) {
        guard let textView = textViewController?.textView else { return }
            
            let originalAppearance = textView.effectiveAppearance
            textView.appearance = NSAppearance(named: .aqua)
            
            let printOperation = NSPrintOperation(view: textView)
            printOperation.printInfo = NSPrintInfo.shared
            printOperation.showsPrintPanel = true
            
            printOperation.run()
            
            textView.appearance = originalAppearance
    }
	
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
