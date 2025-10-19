/*
 * mac-menu
 * A macOS menu application for quick search and selection like dmenu/fzf
 *
 * Author: Sadik Saifi
 * Created: 2025-05-02
 * License: MIT
 */

import Cocoa
import Darwin

/// A custom table row view that provides hover and selection effects
class HoverTableRowView: NSTableRowView {
    /// Draws the selection highlight with rounded corners
    /// - Parameter dirtyRect: The area that needs to be redrawn
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            let selectionRect = NSRect(
                x: 2, y: 2, width: self.bounds.width - 4, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            NSColor.white.withAlphaComponent(0.1).setFill()
            path.fill()
        }
    }

    /// Updates the tracking area for mouse hover effects
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        self.removeTrackingArea(self.trackingAreas.first ?? NSTrackingArea())
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        self.addTrackingArea(
            NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil))
    }

    /// Handles mouse enter events to show hover effect
    /// - Parameter event: The mouse event
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            let hoverRect = NSRect(
                x: 2, y: 2, width: self.bounds.width - 4, height: self.bounds.height - 4)
            let path = NSBezierPath(roundedRect: hoverRect, xRadius: 6, yRadius: 6)
            NSColor.white.withAlphaComponent(0.05).setFill()
            path.fill()
        }
        self.needsDisplay = true
    }

    /// Handles mouse exit events to remove hover effect
    /// - Parameter event: The mouse event
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.needsDisplay = true
    }
}

/// Main application class that implements the menu interface
class MenuApp: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate,
    NSSearchFieldDelegate
{
    // MARK: - Properties

    /// The main application window
    var window: NSWindow!

    /// Table view for displaying and selecting items
    var tableView: NSTableView!

    /// Search field for filtering items
    var searchField: NSSearchField!

    /// Scroll view containing the table view
    var scrollView: NSScrollView!

    /// All available items before filtering
    var allItems: [IndexedItem] = []

    /// Items filtered by search query
    var filteredItems: [IndexedItem] = []

    public struct IndexedItem {
        let index: Int
        let value: String
    }

    /// Fuzzy search result containing the matched string and its score
    private struct FuzzyMatchResult {
        let string: String
        let score: Int
        let positions: [Int]
        var initialIndex: Int = -1
    }

    /// Constants for scoring
    private struct ScoreConfig {
        static let bonusMatch: Int = 16
        static let bonusBoundary: Int = 16
        static let bonusConsecutive: Int = 16
        static let penaltyGapStart: Int = -3
        static let penaltyGapExtension: Int = -1
        static let penaltyNonContiguous: Int = -5
    }

    /// Fuzzy search function implementing fzf's algorithm
    /// - Parameters:
    ///   - pattern: The search pattern to match
    ///   - string: The string to search in
    /// - Returns: A tuple containing whether there's a match and the match result
    private func fuzzyMatch(pattern: String, string: String) -> (Bool, FuzzyMatchResult?) {
        let pattern = pattern.lowercased()
        let string = string.lowercased()

        // Empty pattern matches everything
        if pattern.isEmpty {
            return (true, FuzzyMatchResult(string: string, score: 0, positions: []))
        }

        let patternLength = pattern.count
        let stringLength = string.count

        // If pattern is longer than string, no match possible
        if patternLength > stringLength {
            return (false, nil)
        }

        // Initialize score matrix
        var scores = Array(
            repeating: Array(repeating: 0, count: stringLength + 1), count: patternLength + 1)
        var positions = Array(
            repeating: Array(repeating: [Int](), count: stringLength + 1), count: patternLength + 1)

        // Fill score matrix
        for i in 1...patternLength {
            for j in 1...stringLength {
                let patternChar = pattern[pattern.index(pattern.startIndex, offsetBy: i - 1)]
                let stringChar = string[string.index(string.startIndex, offsetBy: j - 1)]

                if patternChar == stringChar {
                    var score = ScoreConfig.bonusMatch

                    // Bonus for boundary
                    if j == 1 || string[string.index(string.startIndex, offsetBy: j - 2)] == " " {
                        score += ScoreConfig.bonusBoundary
                    }

                    // Bonus for consecutive matches
                    if i > 1 && j > 1
                        && pattern[pattern.index(pattern.startIndex, offsetBy: i - 2)]
                            == string[string.index(string.startIndex, offsetBy: j - 2)]
                    {
                        score += ScoreConfig.bonusConsecutive
                    }

                    let prevScore = scores[i - 1][j - 1]
                    let newScore = prevScore + score

                    // Check if we should extend previous match or start new one
                    if newScore > scores[i - 1][j] + ScoreConfig.penaltyGapStart {
                        scores[i][j] = newScore
                        positions[i][j] = positions[i - 1][j - 1] + [j - 1]
                    } else {
                        scores[i][j] = scores[i - 1][j] + ScoreConfig.penaltyGapStart
                        positions[i][j] = positions[i - 1][j]
                    }
                } else {
                    // Penalty for gaps
                    let gapScore = max(
                        scores[i][j - 1] + ScoreConfig.penaltyGapExtension,
                        scores[i - 1][j] + ScoreConfig.penaltyGapStart
                    )
                    scores[i][j] = gapScore
                    positions[i][j] = positions[i][j - 1]
                }
            }
        }

        // Check if we found a match
        let finalScore = scores[patternLength][stringLength]
        if finalScore > 0 {
            return (
                true,
                FuzzyMatchResult(
                    string: string,
                    score: finalScore,
                    positions: positions[patternLength][stringLength]
                )
            )
        }

        return (false, nil)
    }

    // MARK: - Application Lifecycle

    /// Sets up the application window and UI components
    /// - Parameter notification: The launch notification
    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenSize = NSScreen.main!.frame
        let width: CGFloat = 720
        let itemHeight: CGFloat = 48
        let maxVisibleItems: CGFloat = 5
        let searchHeight: CGFloat = 57
        let borderRadius: CGFloat = 12

        // Calculate fixed height based on maximum visible items
        let height = searchHeight + (itemHeight * maxVisibleItems)

        // Create and configure the main window
        window = NSWindow(
            contentRect: NSRect(
                x: (screenSize.width - width) / 2,
                y: (screenSize.height - height) / 2,
                width: width,
                height: height),
            styleMask: [.titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // Add mouse event monitor to handle clicks outside the window
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return }
            let windowFrame = self.window.frame
            let clickPoint = event.locationInWindow

            // Convert click point to screen coordinates
            let screenPoint = self.window.convertPoint(toScreen: clickPoint)

            // Check if click is outside window frame
            if !windowFrame.contains(screenPoint) {
                NSApp.terminate(nil)
            }
        }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true

        // Configure window shadow
        if let windowFrame = window.contentView?.superview {
            windowFrame.wantsLayer = true
            windowFrame.shadow = NSShadow()
            windowFrame.layer?.shadowColor = NSColor.black.cgColor
            windowFrame.layer?.shadowOpacity = 0.4
            windowFrame.layer?.shadowOffset = NSSize(width: 0, height: -2)
            windowFrame.layer?.shadowRadius = 20
        }

        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hidesOnDeactivate = false

        // Prevent multiple instances from appearing in dock
        NSApp.setActivationPolicy(.accessory)

        // Main container with border
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = borderRadius
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        window.contentView?.addSubview(containerView)

        // Background blur effect
        let blurView = NSVisualEffectView(frame: containerView.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = borderRadius

        // Add subtle inner shadow to enhance depth
        blurView.layer?.masksToBounds = false
        let innerShadow = NSShadow()
        innerShadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        innerShadow.shadowOffset = NSSize(width: 0, height: -1)
        innerShadow.shadowBlurRadius = 3
        blurView.shadow = innerShadow

        // Add subtle gradient overlay for glass effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = containerView.bounds
        gradientLayer.colors = [
            NSColor.white.withAlphaComponent(0.15).cgColor,
            NSColor.white.withAlphaComponent(0.08).cgColor,
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.cornerRadius = borderRadius

        // Overlay view for gradient
        let overlayView = NSView(frame: containerView.bounds)
        overlayView.wantsLayer = true
        overlayView.layer?.cornerRadius = borderRadius
        overlayView.layer?.addSublayer(gradientLayer)

        containerView.addSubview(blurView)
        containerView.addSubview(overlayView)

        // Make overlay view more opaque
        overlayView.alphaValue = 0.5

        // Search field - position at top with vertical centering
        let searchFieldHeight: CGFloat = 36
        let verticalPadding: CGFloat = 8  // Explicit padding for fine-tuning
        let searchFieldY = height - searchHeight + verticalPadding
        let horizontalPadding: CGFloat = 0
        let textPadding: CGFloat = 8

        // Add search icon
        let searchIcon = NSImageView(
            frame: NSRect(
                x: horizontalPadding + 16,
                y: searchFieldY + (searchFieldHeight - 24) / 2,  // Center vertically
                width: 32,
                height: 32))
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
        searchIcon.image = NSImage(
            systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?
            .withSymbolConfiguration(config)
        searchIcon.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        searchIcon.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(searchIcon)

        // Configure search field
        searchField = NSSearchField(
            frame: NSRect(
                x: horizontalPadding + textPadding + 48,
                y: searchFieldY,
                width: width - (horizontalPadding + textPadding) * 2 - 48,
                height: searchFieldHeight))
        searchField.wantsLayer = true
        searchField.focusRingType = .none
        searchField.delegate = self

        // Create a custom clear appearance
        let clearAppearance = NSAppearance(named: .darkAqua)
        searchField.appearance = clearAppearance

        // Configure search field cell
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.font = NSFont.systemFont(ofSize: 24, weight: .regular)
            cell.placeholderString = "Search..."
            cell.searchButtonCell = nil
            cell.cancelButtonCell = nil
            cell.bezelStyle = .squareBezel
            cell.backgroundColor = NSColor.clear
            cell.drawsBackground = false
            cell.sendsActionOnEndEditing = true
            cell.isScrollable = true
            cell.usesSingleLineMode = true

            // Set proper text attributes for padding
            let style = NSMutableParagraphStyle()
            style.firstLineHeadIndent = 8
            style.headIndent = 8
            let attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: style,
                .font: NSFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: NSColor.white,
            ]
            cell.placeholderAttributedString = NSAttributedString(
                string: "Search...", attributes: attributes)
        }

        // Remove any border or background from the search field itself
        searchField.layer?.borderWidth = 0
        searchField.layer?.cornerRadius = 0
        searchField.layer?.masksToBounds = true
        searchField.textColor = NSColor.white
        searchField.backgroundColor = NSColor.clear
        searchField.drawsBackground = false
        searchField.isBezeled = false
        searchField.isBordered = false

        // Force the field editor to be transparent
        if let fieldEditor = window.fieldEditor(false, for: searchField) as? NSTextView {
            fieldEditor.backgroundColor = NSColor.clear
            fieldEditor.drawsBackground = false
        }

        // Remove the default search field styling from all subviews
        searchField.subviews.forEach { subview in
            subview.wantsLayer = true
            if let layer = subview.layer {
                layer.backgroundColor = NSColor.clear.cgColor
            }
            if let textField = subview as? NSTextField {
                textField.backgroundColor = NSColor.clear
                textField.drawsBackground = false
                textField.isBezeled = false
                textField.isBordered = false
            }
        }

        containerView.addSubview(searchField)

        // Separator line
        let separator = NSView(
            frame: NSRect(
                x: horizontalPadding,
                y: height - searchHeight,
                width: width - horizontalPadding * 2,
                height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        containerView.addSubview(separator)

        // Configure table view
        let tableHeight = height - searchHeight
        let sideMargin: CGFloat = 8
        scrollView = NSScrollView(
            frame: NSRect(
                x: sideMargin,
                y: sideMargin,
                width: width - (sideMargin * 2),
                height: tableHeight - sideMargin))
        scrollView.hasVerticalScroller = true
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.backgroundColor = NSColor.clear
        scrollView.drawsBackground = false

        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = NSColor.clear
        tableView.selectionHighlightStyle = .regular
        tableView.enclosingScrollView?.drawsBackground = false
        tableView.rowHeight = itemHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.action = #selector(handleClick)
        tableView.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ItemColumn"))
        column.width = scrollView.frame.width
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        containerView.addSubview(scrollView)

        window.makeFirstResponder(searchField)
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Ensure window gets and maintains focus
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()

        // Add focus observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )

        // Window-level key event monitoring
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Navigation keys
            if event.keyCode == 126  // Up arrow
                || (event.modifierFlags.contains(.control) && event.keyCode == 35)
            {  // Ctrl + P
                self.moveSelection(offset: -1)
                return nil
            }

            if event.keyCode == 125  // Down arrow
                || (event.modifierFlags.contains(.control) && event.keyCode == 45)
            {  // Ctrl + N
                self.moveSelection(offset: 1)
                return nil
            }

            // Enter key
            if event.keyCode == 36 {
                self.selectCurrentRow()
                return nil
            }

            // Escape key
            if event.keyCode == 53 {
                NSApp.terminate(nil)
                return nil
            }

            return event
        }

        loadInput()
    }

    // MARK: - Input Handling

    /// Loads input from stdin and populates the items list
    func loadInput() {
        // Check if stdin is a terminal
        if isatty(FileHandle.standardInput.fileDescriptor) != 0 {
            print("Error: No input provided. Please pipe some input into mac-menu.")
            print("Use 'mac-menu --help' to learn more about how to use the program.")
            NSApp.terminate(nil)
            return
        }

        // Try to read available input
        if let input = try? String(
            data: FileHandle.standardInput.readToEnd() ?? Data(), encoding: .utf8)
        {
            if input.isEmpty {
                print("Error: No input provided. Please pipe some input into mac-menu.")
                print("Use 'mac-menu --help' to learn more about how to use the program.")
                NSApp.terminate(nil)
                return
            }
            let lines = input.components(separatedBy: .newlines).filter { !$0.isEmpty }
            allItems = lines.enumerated().map { IndexedItem(index: $0.offset, value: $0.element) }
            filteredItems = allItems
            tableView.reloadData()
            selectRow(index: 0)
        } else {
            print("Error: No input provided. Please pipe some input into mac-menu.")
            print("Use 'mac-menu --help' to learn more about how to use the program.")
            NSApp.terminate(nil)
        }
    }

    // MARK: - Table View Data Source

    /// Returns the number of rows in the table view
    /// - Parameter tableView: The table view requesting the information
    /// - Returns: The number of rows
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    /// Provides the view for a table column
    /// - Parameters:
    ///   - tableView: The table view requesting the view
    ///   - tableColumn: The column for which to provide the view
    ///   - row: The row for which to provide the view
    /// - Returns: The view to display in the table cell
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let cellPadding: CGFloat = 4
        let cell = NSTextField(labelWithString: filteredItems[row].value)
        cell.textColor = NSColor.white
        cell.backgroundColor = NSColor.clear
        cell.isBordered = false
        cell.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        cell.lineBreakMode = .byTruncatingTail

        // Create container for proper padding and hover state
        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: tableView.frame.width, height: tableView.rowHeight))
        container.wantsLayer = true

        // Center the cell vertically in its container and add side padding
        let cellHeight = cell.cell?.cellSize.height ?? 20
        let yOffset = (container.frame.height - cellHeight) / 2
        cell.frame = NSRect(
            x: cellPadding,
            y: yOffset,
            width: container.frame.width - (cellPadding * 2),
            height: cellHeight)

        container.addSubview(cell)
        return container
    }

    /// Provides a custom row view for the table
    /// - Parameters:
    ///   - tableView: The table view requesting the row view
    ///   - row: The row for which to provide the view
    /// - Returns: A custom row view with hover effects
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = HoverTableRowView()
        rowView.wantsLayer = true
        rowView.backgroundColor = NSColor.clear
        return rowView
    }

    /// Returns the height for a specific row
    /// - Parameters:
    ///   - tableView: The table view requesting the height
    ///   - row: The row for which to return the height
    /// - Returns: The height of the row
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 48  // Consistent row height
    }

    /// Called when a row view is added to the table
    /// - Parameters:
    ///   - tableView: The table view
    ///   - rowView: The row view that was added
    ///   - row: The row index
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        rowView.backgroundColor = .clear
    }

    // MARK: - Table View Delegate

    /// Determines if a row should be selectable
    /// - Parameters:
    ///   - tableView: The table view
    ///   - row: The row to check
    /// - Returns: true if the row should be selectable
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    /// Called when the selection changes in the table view
    /// - Parameter notification: The notification object
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Nothing needed unless we want side effects on selection
    }

    // MARK: - Search Field Delegate

    /// Called when the search field text changes
    /// - Parameter obj: The notification object
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        let query = searchField.stringValue

        if query.isEmpty {
            filteredItems = allItems
        } else {
            // Get matches with scores
            let matches = allItems.compactMap { item -> FuzzyMatchResult? in
                let (isMatch, result) = fuzzyMatch(pattern: query, string: item.value)
                guard isMatch, var unwrappedResult = result else { return nil }
                unwrappedResult.initialIndex = item.index
                return unwrappedResult
            }
            .sorted { $0.score > $1.score }

            // Extract just the strings in order of score
            filteredItems = matches.map { IndexedItem(index: $0.initialIndex, value: $0.string) }
        }

        tableView.reloadData()
        if !filteredItems.isEmpty {
            selectRow(index: 0)
        }
    }

    /// Handles special key commands in the search field
    /// - Parameters:
    ///   - control: The control sending the command
    ///   - textView: The text view handling the input
    ///   - commandSelector: The selector for the command
    /// - Returns: true if the command was handled
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
        -> Bool
    {
        return false  // Let the default key handling work
    }

    // MARK: - Selection Handling

    /// Moves the selection up or down by the specified offset
    /// - Parameter offset: The number of rows to move (negative for up, positive for down)
    func moveSelection(offset: Int) {
        let current = tableView.selectedRow
        guard filteredItems.count > 0 else { return }

        var next = current + offset
        if next < 0 { next = 0 }
        if next >= filteredItems.count { next = filteredItems.count - 1 }

        selectRow(index: next)
    }

    /// Selects a specific row in the table
    /// - Parameter index: The index of the row to select
    func selectRow(index: Int) {
        if filteredItems.isEmpty { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    /// Handles the selection of the current row
    func selectCurrentRow() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filteredItems.count else { return }
        if returnIndexFlag {
            print(filteredItems[row].value, filteredItems[row].index)
        } else {

            print(filteredItems[row].value)
        }
        fflush(stdout)
        NSApp.terminate(nil)
    }

    /// Handles click events on table rows
    @objc func handleClick() {
        selectCurrentRow()
    }

    // MARK: - Window Focus Handling

    /// Handles window focus loss
    @objc func windowDidResignKey(_ notification: Notification) {
        // Regain focus if we're still the active window
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private let helpFlags: Set<String> = ["-h", "--help", "help"]
private let versionFlags: Set<String> = ["-v", "--version", "version"]
private let returnIndexFlags: Set<String> = ["-i", "--index"]
private var returnIndexFlag: Bool = false

private func handleEarlyFlags() {
    let args = Set(CommandLine.arguments.dropFirst())

    if !helpFlags.isDisjoint(with: args) {
        print(
            """
            mac-menu – does wonderful things with piped input.

            USAGE:
              mac-menu [options]

            OPTIONS:
              -h, --help,   help      Show this help and quit
              -v, --version,version   Show version and quit
            """)
        exit(EXIT_SUCCESS)
    }

    if !versionFlags.isDisjoint(with: args) {
        let version = "0.0.1"
        print("mac-menu \(version)")
        exit(EXIT_SUCCESS)
    }

    if !returnIndexFlags.isDisjoint(with: args) {
        returnIndexFlag = true
    }
}

handleEarlyFlags()

// Start app
let app = NSApplication.shared
let delegate = MenuApp()
app.delegate = delegate
app.run()
