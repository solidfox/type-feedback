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

    override func windowDidLoad() {
        super.windowDidLoad()
		
		if let window = window {
			var darkMode = false
			
			if #available(OSX 10.14, *) {
				darkMode = window.effectiveAppearance.name == .darkAqua
			}
			
			let lightBgHexColor:UInt32 = 0xfcedc7
			
			if !darkMode {
				window.backgroundColor = DynamicColor(hex:lightBgHexColor)
			} else {
				window.backgroundColor = DynamicColor(hex:lightBgHexColor).inverted()
			}
			window.delegate = self
		}
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
	
	func windowShouldClose(_ sender: NSWindow) -> Bool {
		NSApp.perform(#selector(NSApp.terminate), with: nil, afterDelay: 0.0)
		return false
	}
}
