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
		
		window?.backgroundColor = DynamicColor(hex:0xfcedc7)
		window?.delegate = self
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
	
	func windowShouldClose(_ sender: Any) -> Bool {
		NSApp.perform(#selector(NSApp.terminate), with: nil, afterDelay: 0.0)
		return false
	}

}
