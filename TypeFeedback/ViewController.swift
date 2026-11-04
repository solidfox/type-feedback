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

		showDocumentText()
	}

	override var representedObject: Any? {
		didSet {
			showDocumentText()
		}
	}
	
	/// Lets the text view edit the document's text storage directly, so the document always holds what is on screen.
	func showDocumentText() {
		guard isViewLoaded, let document = representedObject as? Document else { return }
		textView.layoutManager?.replaceTextStorage(document.textStorage)
		textView.font = Document.textFont
		// Continue writing where the text ends, as before documents.
		textView.setSelectedRange(NSRange(location: document.textStorage.length, length: 0))
		textView.scrollRangeToVisible(textView.selectedRange())
	}

    

}

