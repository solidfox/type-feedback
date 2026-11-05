//
//  FocusMode.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-05.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

/// Focus mode is the window's full screen: nothing but the text, in a calm column in the middle of the screen.
/// The sidebar hides and the toolbar only slides down when the pointer touches the top of the screen.
/// View › Fokusläge, ⌃⌘F, the toolbar button and the green window button all go there; Esc or ⌃⌘F come back.
enum FocusLayout {

	/// A comfortable line for reading: about 65 letters, whatever the font size.
	static let lettersPerLine: CGFloat = 65
	/// The column never comes closer than this to the edges of the screen.
	static let minimumMargin: CGFloat = 40
	/// While writing, the line being written stays above this share of the screen height.
	static let writingLineLimit: CGFloat = 0.7

	/// Ordinary Swedish text, so the width of an average letter comes out right for the font.
	private static let sampleText = "Det var en gång en liten räv som bodde i en grotta i skogen. Hon tyckte om att läsa."

	static func columnWidth(for font: NSFont) -> CGFloat {
		let sampleWidth = (sampleText as NSString).size(withAttributes: [.font: font]).width
		return ceil(sampleWidth / CGFloat(sampleText.count) * lettersPerLine)
	}

	/// The space on each side of the text and above and below it, for a view of the given size.
	static func textInset(viewSize: NSSize, columnWidth: CGFloat) -> NSSize {
		let horizontal = max(minimumMargin, floor((viewSize.width - columnWidth) / 2))
		// Room above the first line, and below the last one so it can be written in the upper part of the screen.
		let vertical = max(minimumMargin, floor(viewSize.height * (1 - writingLineLimit)))
		return NSSize(width: horizontal, height: vertical)
	}

	/// Where to scroll so the line being written is no lower than the writing line limit; nil when it already is.
	/// In the text view's flipped coordinates, where y grows downward.
	static func scrollOrigin(keeping caret: NSRect, visible: NSRect) -> CGFloat? {
		let limit = visible.minY + visible.height * writingLineLimit
		guard caret.maxY > limit else { return nil }
		return caret.maxY - visible.height * writingLineLimit
	}
}

/// The writing area's text view.
final class WritingTextView: NSTextView {

	/// Esc leaves focus mode, as it leaves a full screen video. Otherwise Esc does what it always does in text.
	override func cancelOperation(_ sender: Any?) {
		if let window = window, window.styleMask.contains(.fullScreen) {
			window.toggleFullScreen(sender)
			return
		}
		super.cancelOperation(sender)
	}
}
