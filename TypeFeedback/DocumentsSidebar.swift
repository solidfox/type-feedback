//
//  DocumentsSidebar.swift
//  TypeFeedback
//
//  Created by Daniel Schlaug on 2026-11-04.
//  Copyright © 2026 Daniel Schlaug. All rights reserved.
//

import Cocoa

/// Each document window: the documents sidebar on the left, the text on the right.
final class DocumentSplitViewController: NSSplitViewController {

	static let sidebarWidth: CGFloat = 250

	let sidebarItem: NSSplitViewItem
	let textItem: NSSplitViewItem
	let sidebarViewController: DocumentsSidebarViewController

	init(textViewController: NSViewController) {
		sidebarViewController = DocumentsSidebarViewController()
		sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
		sidebarItem.minimumThickness = 190
		sidebarItem.maximumThickness = 400
		sidebarItem.canCollapse = true
		textItem = NSSplitViewItem(viewController: textViewController)
		textItem.minimumThickness = 320
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not used")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		splitView.dividerStyle = .thin
		addSplitViewItem(sidebarItem)
		addSplitViewItem(textItem)
		sidebarItem.isCollapsed = UserDefaults.standard.bool(forKey: AppDefaults.keys.sidebarHidden.rawValue)
	}

	var isSidebarVisible: Bool {
		return !sidebarItem.isCollapsed
	}

	/// Shows or hides the sidebar without changing what new windows do. For modes such as focus mode.
	func setSidebarVisible(_ visible: Bool, animated: Bool) {
		if animated {
			sidebarItem.animator().isCollapsed = !visible
		} else {
			sidebarItem.isCollapsed = !visible
		}
	}

	/// View › Show/Hide Sidebar, ⌃⌘S and the toolbar button. New windows open the way the sidebar was last left.
	override func toggleSidebar(_ sender: Any?) {
		let willHide = !sidebarItem.isCollapsed
		super.toggleSidebar(sender)
		UserDefaults.standard.set(willHide, forKey: AppDefaults.keys.sidebarHidden.rawValue)
	}
}

/// The list of texts in the TypeFeedback folder. Clicking one opens it in its own window, or brings that window forward.
final class DocumentsSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {

	private let tableView = NSTableView()
	private let emptyLabel = NSTextField(wrappingLabelWithString: "Här hamnar dina texter.")
	private var items: [DocumentLibrary.Item] = []
	private static let cellIdentifier = NSUserInterfaceItemIdentifier("DocumentCell")

	override func loadView() {
		let background = ColorFillView(color: { Palette.sidebar })

		let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Document"))
		column.resizingMask = .autoresizingMask
		tableView.addTableColumn(column)
		tableView.headerView = nil
		tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
		tableView.rowHeight = 66
		tableView.intercellSpacing = NSSize(width: 0, height: 4)
		tableView.backgroundColor = .clear
		tableView.focusRingType = .none
		// Typing always goes to the text, even after clicking in the list.
		tableView.refusesFirstResponder = true
		if #available(OSX 11.0, *) {
			tableView.style = .plain
		}
		tableView.dataSource = self
		tableView.delegate = self
		tableView.target = self
		tableView.action = #selector(openClickedDocument(_:))
		tableView.setAccessibilityLabel("Texter")

		let menu = NSMenu()
		menu.delegate = self
		menu.addItem(withTitle: "Flytta till papperskorgen…", action: #selector(moveClickedDocumentToTrash(_:)), keyEquivalent: "").target = self
		tableView.menu = menu

		// The same as File › New and ⌘N, where a child can see it.
		let newTextButton = NSButton(title: "Ny text", target: NSDocumentController.shared, action: #selector(NSDocumentController.newDocument(_:)))
		newTextButton.bezelStyle = .regularSquare
		newTextButton.image = NSImage(named: NSImage.addTemplateName)
		newTextButton.imagePosition = .imageLeading
		newTextButton.font = Document.font(size: 15)
		newTextButton.toolTip = "Börja på en ny text (⌘N)"
		newTextButton.refusesFirstResponder = true
		newTextButton.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(newTextButton)

		let scrollView = NSScrollView()
		scrollView.documentView = tableView
		scrollView.drawsBackground = false
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.automaticallyAdjustsContentInsets = false
		scrollView.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 10, right: 0)
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(scrollView)

		emptyLabel.font = Document.font(size: 15)
		emptyLabel.textColor = .secondaryLabelColor
		emptyLabel.alignment = .center
		emptyLabel.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(emptyLabel)

		NSLayoutConstraint.activate([
			newTextButton.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
			newTextButton.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
			newTextButton.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
			newTextButton.heightAnchor.constraint(equalToConstant: 36),
			scrollView.topAnchor.constraint(equalTo: newTextButton.bottomAnchor, constant: 8),
			scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
			scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
			emptyLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
			emptyLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -20),
			emptyLabel.topAnchor.constraint(equalTo: newTextButton.bottomAnchor, constant: 30),
		])
		background.frame = NSRect(x: 0, y: 0, width: DocumentSplitViewController.sidebarWidth, height: 400)
		view = background
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(libraryDidChange(_:)), name: DocumentLibrary.didChangeNotification, object: nil)
		DocumentLibrary.shared.start()
		showItems()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		showItems()
	}

	@objc private func libraryDidChange(_ notification: Notification) {
		showItems()
	}

	private var currentDocumentURL: URL? {
		return (view.window?.windowController?.document as? NSDocument)?.fileURL
	}

	private func showItems() {
		items = DocumentLibrary.shared.items
		tableView.reloadData()
		emptyLabel.isHidden = !items.isEmpty
		showCurrentDocument()
	}

	/// Highlights the text shown in this window. Also called when the window's text is saved, renamed or moved.
	func showCurrentDocument() {
		guard isViewLoaded else { return }
		let current = currentDocumentURL?.standardizedFileURL
		if let row = items.firstIndex(where: { $0.url.standardizedFileURL == current }) {
			tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
		} else {
			tableView.deselectAll(nil)
		}
	}

	@objc private func openClickedDocument(_ sender: Any?) {
		let row = tableView.clickedRow
		guard items.indices.contains(row) else { return }
		DocumentLibrary.shared.open(items[row])
	}

	@objc private func moveClickedDocumentToTrash(_ sender: Any?) {
		let row = tableView.clickedRow
		guard items.indices.contains(row), let window = view.window else { return }
		let item = items[row]
		// An open text may be renamed while the question is showing; then trash the document, not the old file name.
		let openDocument = NSDocumentController.shared.document(for: item.url)
		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = "Vill du flytta ”\(item.name)” till papperskorgen?"
		alert.informativeText = "Du kan hämta tillbaka texten från papperskorgen."
		let trashButton = alert.addButton(withTitle: "Flytta till papperskorgen")
		let cancelButton = alert.addButton(withTitle: "Avbryt")
		// Return must not throw a text away by accident; only a click does. Escape cancels.
		trashButton.keyEquivalent = ""
		cancelButton.keyEquivalent = "\u{1b}"
		alert.beginSheetModal(for: window) { response in
			guard response == .alertFirstButtonReturn else { return }
			if let document = openDocument {
				DocumentLibrary.shared.moveToTrash(document)
			} else {
				DocumentLibrary.shared.moveToTrash(item)
			}
		}
	}

	func menuNeedsUpdate(_ menu: NSMenu) {
		menu.items.forEach { $0.isHidden = !items.indices.contains(tableView.clickedRow) }
	}

	// MARK: Table

	func numberOfRows(in tableView: NSTableView) -> Int {
		return items.count
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let cell = tableView.makeView(withIdentifier: DocumentsSidebarViewController.cellIdentifier, owner: self) as? DocumentCellView ?? DocumentCellView()
		cell.identifier = DocumentsSidebarViewController.cellIdentifier
		cell.show(items[row])
		return cell
	}

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		return DocumentRowView()
	}

	/// The highlight always marks this window's own text; clicking another text opens it instead of moving the highlight.
	func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
		return tableView.selectedRowIndexes
	}
}

/// One text in the sidebar: its name, and when it was last changed.
private final class DocumentCellView: NSTableCellView {

	private let nameField = NSTextField(labelWithString: "")
	private let dateField = NSTextField(labelWithString: "")

	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .short
		formatter.doesRelativeDateFormatting = true
		return formatter
	}()

	init() {
		super.init(frame: NSRect(x: 0, y: 0, width: DocumentSplitViewController.sidebarWidth, height: 66))
		nameField.font = Document.font(size: 16)
		nameField.textColor = .labelColor
		nameField.lineBreakMode = .byTruncatingTail
		dateField.font = Document.font(size: 12)
		dateField.textColor = .secondaryLabelColor
		dateField.lineBreakMode = .byTruncatingTail
		for field in [nameField, dateField] {
			field.translatesAutoresizingMaskIntoConstraints = false
			field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
			addSubview(field)
		}
		textField = nameField
		NSLayoutConstraint.activate([
			nameField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
			nameField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
			nameField.topAnchor.constraint(equalTo: topAnchor, constant: 8),
			dateField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
			dateField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
			dateField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 0),
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not used")
	}

	func show(_ item: DocumentLibrary.Item) {
		nameField.stringValue = item.name
		dateField.stringValue = DocumentCellView.dateFormatter.string(from: item.modificationDate)
		toolTip = item.name
	}
}

/// A soft, rounded highlight instead of the system's strong blue one.
private final class DocumentRowView: NSTableRowView {

	override var isEmphasized: Bool {
		get { return false }
		set {}
	}

	override func drawSelection(in dirtyRect: NSRect) {
		Palette.selection.setFill()
		NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 0), xRadius: 10, yRadius: 10).fill()
	}
}

/// A view filled with a colour that is looked up each time it draws, so it follows light and dark mode.
final class ColorFillView: NSView {

	private let color: () -> NSColor

	init(color: @escaping () -> NSColor) {
		self.color = color
		super.init(frame: .zero)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not used")
	}

	override var isOpaque: Bool {
		return true
	}

	override func draw(_ dirtyRect: NSRect) {
		color().setFill()
		dirtyRect.fill()
	}
}
