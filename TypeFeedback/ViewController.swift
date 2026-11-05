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
		// The text view grows with its scroll view; the scroll view's constraints keep it narrow outside focus mode.
		textView.maxSize.width = CGFloat.greatestFiniteMagnitude
		normalTextInset = textView.textContainerInset
		autohidesScrollersNormally = textView.enclosingScrollView?.autohidesScrollers ?? false
		normalLayout = storyboardLayout()

		showDocumentText()
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSText.didChangeNotification, object: textView)
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

	// MARK: Focus mode

	/// True while the window is in focus mode: the text fills the screen, in a centred column.
	var isFocused = false {
		didSet {
			guard isFocused != oldValue, isViewLoaded, let scrollView = textView.enclosingScrollView else { return }
			if isFocused {
				NSLayoutConstraint.deactivate(normalLayout)
				NSLayoutConstraint.activate(focusLayout)
			} else {
				NSLayoutConstraint.deactivate(focusLayout)
				NSLayoutConstraint.activate(normalLayout)
				textView.textContainerInset = normalTextInset
			}
			scrollView.autohidesScrollers = isFocused || autohidesScrollersNormally
			view.needsLayout = true
		}
	}

	private var normalTextInset = NSSize.zero
	private var autohidesScrollersNormally = false
	private var normalLayout: [NSLayoutConstraint] = []

	/// The storyboard's layout: a scroll view at most 800 points wide, with 20 points around it.
	private func storyboardLayout() -> [NSLayoutConstraint] {
		guard let scrollView = textView.enclosingScrollView else { return [] }
		return view.constraints.filter { $0.firstItem === scrollView || $0.secondItem === scrollView }
			+ scrollView.constraints.filter { $0.firstItem === scrollView && $0.secondItem == nil && $0.firstAttribute == .width }
	}

	/// In focus mode the scroll view fills the screen, so scrolling works anywhere and the scroller sits at the edge.
	private lazy var focusLayout: [NSLayoutConstraint] = {
		guard let scrollView = textView.enclosingScrollView else { return [] }
		return [
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		]
	}()

	override func viewDidLayout() {
		super.viewDidLayout()
		if isFocused {
			centerText()
		}
	}

	/// Centres a column about 65 letters wide, measured in the font being written in, so bigger letters get a wider column.
	private func centerText() {
		guard let clipView = textView.enclosingScrollView?.contentView else { return }
		let font = textView.typingAttributes[.font] as? NSFont ?? Document.textFont
		let inset = FocusLayout.textInset(viewSize: clipView.bounds.size, columnWidth: FocusLayout.columnWidth(for: font))
		if textView.textContainerInset != inset {
			textView.textContainerInset = inset
		}
	}

	/// In focus mode the line being written stays in the upper part of the screen, never squeezed against the bottom edge.
	@objc private func textDidChange(_ notification: Notification) {
		guard isFocused else { return }
		// Format › Bigger and Smaller change the font, and with it the width of the column.
		centerText()
		// After the text view has scrolled the new text into view itself.
		DispatchQueue.main.async { [weak self] in
			self?.keepWritingLineUp()
		}
	}

	private func keepWritingLineUp() {
		guard isFocused, let window = textView.window else { return }
		let screenRect = textView.firstRect(forCharacterRange: NSRange(location: textView.selectedRange().location, length: 0), actualRange: nil)
		let caret = textView.convert(window.convertFromScreen(screenRect), from: nil)
		let visible = textView.visibleRect
		if let y = FocusLayout.scrollOrigin(keeping: caret, visible: visible) {
			textView.scroll(NSPoint(x: visible.minX, y: y))
		}
	}
}

