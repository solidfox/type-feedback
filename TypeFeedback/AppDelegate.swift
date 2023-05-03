//
//  AppDelegate.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2017-03-10.
//  Copyright © 2017 Daniel Schlaug. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

    @IBAction func printFromMenu(_ sender: Any) {
        if let mainWindowController = NSApp.mainWindow?.windowController as? WindowController {
            mainWindowController.print(sender)
        }
    }
    
}

