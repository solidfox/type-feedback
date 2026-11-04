//
//  DocumentPrinting.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

/// ⌘P, File > Print… and the toolbar's print button all send printDocument:, which NSDocument turns into this
/// print operation. Page Setup… (runPageLayout:) edits the document's printInfo, which is used here.
extension Document {

	override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
		let printInfo = self.printInfo.copy() as! NSPrintInfo
		printInfo.dictionary().addEntries(from: printSettings)
		DocumentPrintView.applyPageLayout(to: printInfo)

		let printView = DocumentPrintView(text: textStorage.string, title: displayName, printInfo: printInfo)
		let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
		printOperation.jobTitle = displayName
		printOperation.printPanel.options.formUnion([.showsPaperSize, .showsOrientation])
		return printOperation
	}

}

/// An off-screen copy of the text laid out for paper: black text on white, wrapped to the page width rather than
/// the window width, with the document name at the top of each page and page numbers at the bottom.
class DocumentPrintView: NSTextView {

	static let textFont = NSFont(descriptor: Document.textFont.fontDescriptor, size: 16) ?? NSFont.systemFont(ofSize: 16)
	static let marginFont = NSFont.systemFont(ofSize: 10)

	/// 2 cm on every side; the name and page number sit in the top and bottom margins.
	static let margin: CGFloat = 2 / 2.54 * 72

	private let title: String
	/// A text view made in code does not own its text storage, so the view keeps it alive.
	private let printStorage = NSTextStorage()

	static func applyPageLayout(to printInfo: NSPrintInfo) {
		printInfo.leftMargin = margin
		printInfo.rightMargin = margin
		printInfo.topMargin = margin
		printInfo.bottomMargin = margin
		printInfo.horizontalPagination = .fit
		printInfo.verticalPagination = .automatic
		printInfo.isHorizontallyCentered = false
		printInfo.isVerticallyCentered = false
	}

	init(text: String, title: String, printInfo: NSPrintInfo) {
		self.title = title
		let layoutManager = NSLayoutManager()
		printStorage.addLayoutManager(layoutManager)
		let textContainer = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
		layoutManager.addTextContainer(textContainer)
		super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 400), textContainer: textContainer)
		// Always print like light mode, whatever the screen looks like.
		appearance = NSAppearance(named: .aqua)
		backgroundColor = .white
		drawsBackground = true
		isEditable = false
		isVerticallyResizable = true
		isHorizontallyResizable = false
		minSize = .zero
		maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
		textContainerInset = .zero
		textContainer.lineFragmentPadding = 0
		textContainer.widthTracksTextView = true

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.lineHeightMultiple = 1.1
		let attributes: [NSAttributedString.Key: Any] = [.font: DocumentPrintView.textFont, .foregroundColor: NSColor.black, .paragraphStyle: paragraphStyle]
		printStorage.setAttributedString(NSAttributedString(string: text, attributes: attributes))

		fitWidth(to: printInfo)
	}

	required init?(coder: NSCoder) {
		fatalError("DocumentPrintView is only made in code")
	}

	/// Wraps the text to the printable width of the paper and grows the view to hold all of it.
	private func fitWidth(to printInfo: NSPrintInfo) {
		let scale = (printInfo.dictionary()[NSPrintInfo.AttributeKey.scalingFactor] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 1
		let width = (printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin) / max(scale, 0.01)
		setFrameSize(NSSize(width: width, height: frame.height))
		if let layoutManager = layoutManager, let textContainer = textContainer {
			layoutManager.ensureLayout(for: textContainer)
		}
		sizeToFit()
	}

	/// Paper size, orientation and scale can change in the print panel; follow them before the pages are counted.
	override func knowsPageRange(_ range: NSRangePointer) -> Bool {
		if let printInfo = NSPrintOperation.current?.printInfo {
			fitWidth(to: printInfo)
		}
		return super.knowsPageRange(range)
	}

	override func drawPageBorder(with borderSize: NSSize) {
		super.drawPageBorder(with: borderSize)
		guard let printOperation = NSPrintOperation.current else { return }
		let printInfo = printOperation.printInfo
		let truncating = NSMutableParagraphStyle()
		truncating.lineBreakMode = .byTruncatingTail
		let attributes: [NSAttributedString.Key: Any] = [.font: DocumentPrintView.marginFont, .foregroundColor: NSColor.darkGray, .paragraphStyle: truncating]

		// The y of a line of text centred in the top or bottom margin, whichever way up the page is drawn.
		let isFlipped = NSGraphicsContext.current?.isFlipped ?? false
		func y(centering height: CGFloat, inMargin margin: CGFloat, atTop: Bool) -> CGFloat {
			let fromEdge = (margin - height) / 2
			return atTop == isFlipped ? fromEdge : borderSize.height - fromEdge - height
		}

		let header = NSAttributedString(string: title, attributes: attributes)
		let headerHeight = header.size().height
		let headerRect = NSRect(x: printInfo.leftMargin, y: y(centering: headerHeight, inMargin: printInfo.topMargin, atTop: true), width: borderSize.width - printInfo.leftMargin - printInfo.rightMargin, height: headerHeight)
		header.draw(with: headerRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])

		// Most texts fit on one page; "1 / 1" would only be clutter there.
		let pageCount = printOperation.pageRange.length
		guard pageCount > 1 else { return }
		let footer = NSAttributedString(string: "\(printOperation.currentPage) / \(pageCount)", attributes: attributes)
		let footerSize = footer.size()
		footer.draw(at: NSPoint(x: (borderSize.width - footerSize.width) / 2, y: y(centering: footerSize.height, inMargin: printInfo.bottomMargin, atTop: false)))
	}

}
