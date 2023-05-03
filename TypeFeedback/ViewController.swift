//
//  ViewController.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2017-03-10.
//  Copyright © 2017 Daniel Schlaug. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSToolbarDelegate {

	@IBOutlet var textView: NSTextView!
	
	let textViewDelegate = TextViewVoiceFeedback()
    
	override func viewDidLoad() {
		super.viewDidLoad()
		textView.delegate = textViewDelegate
		
		textView.font = NSFont(name: "OpenDyslexic", size: 20)
		
		if let textViewContents = NSUserDefaultsController.shared.defaults.string(forKey: "TextViewContents") {
			textView.string = textViewContents
		}
		
		// Do any additional setup after loading the view.
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

    

}

