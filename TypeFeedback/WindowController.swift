//
//  WindowController.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2017-03-11.
//  Copyright © 2017 Daniel Schlaug. All rights reserved.
//

import Cocoa
import DynamicColor

class WindowController: NSWindowController, NSWindowDelegate {
	@IBAction func onSpellingSegmentedControlChange(_ sender: NSSegmentedControl) {
		NSUserDefaultsController.shared.defaults.set(sender.selectedSegment, forKey: AppDefaults.keys.spellingMode.rawValue)
		NotificationCenter.default.post(Notification(name: .spellingModeUpdated))
	}
	@IBOutlet weak var spellingSegmentedControl: NSSegmentedControl!
	
    override func windowDidLoad() {
        super.windowDidLoad()
		
		if let window = window {
			var darkMode = false
			
			if #available(OSX 10.14, *) {
				darkMode = window.effectiveAppearance.name == .darkAqua
			}
			
			let lightBgHexColor:UInt64 = 0xfcedc7
			
			if !darkMode {
				window.backgroundColor = DynamicColor(hex:lightBgHexColor)
			} else {
				window.backgroundColor = DynamicColor(hex:lightBgHexColor).inverted()
			}
			window.delegate = self
		}
		
		showSpellingMode()
		NotificationCenter.default.addObserver(self, selector: #selector(onSpellingModeUpdated(_:)), name: .spellingModeUpdated, object: nil)
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
	
	/// The setting is shared by all windows, so a change in one window updates the others.
	@objc func onSpellingModeUpdated(_ notification: Notification) {
		showSpellingMode()
	}
	
	func showSpellingMode() {
		spellingSegmentedControl.selectedSegment = (NSUserDefaultsController.shared.defaults.integer(forKey: AppDefaults.keys.spellingMode.rawValue))
	}
}
