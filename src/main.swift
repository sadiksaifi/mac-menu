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

// Models, Core, IO, and UI components are now in separate modules

/// Custom window that accepts keyboard input when borderless
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Main application class that implements the menu interface
class MenuApp: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    // MARK: - Dependencies (injected for testability)

    /// Input loader for reading stdin
    private let inputLoader: InputLoaderProtocol

    /// Search engine for fuzzy matching
    private let searchEngine: SearchEngineProtocol

    /// Output writer for stdout
    private let outputWriter: OutputWriterProtocol

    // MARK: - Properties

    /// The main application window
    var window: NSWindow!
    
    /// Table view for displaying and selecting items
    var tableView: NSTableView!
    
    /// Search field for filtering items
    var searchField: NSSearchField!
    
    /// Scroll view containing the table view
    var scrollView: NSScrollView!

    /// Loading indicator label shown while reading stdin
    var loadingLabel: NSTextField?

    /// Container view for the main UI
    var containerView: NSView!

    /// All available items before filtering (with cached lowercase)
    var allItems: [SearchableItem] = []

    /// Items filtered by search query (with cached lowercase)
    var filteredItems: [SearchableItem] = []

    /// Timer for debouncing search input
    private var searchDebounceTimer: Timer?

    // MARK: - Initialization

    /// Creates a new MenuApp with injectable dependencies
    /// - Parameters:
    ///   - inputLoader: The input loader to use (defaults to stdin)
    ///   - searchEngine: The search engine to use (defaults to fuzzy matching)
    ///   - outputWriter: The output writer to use (defaults to stdout)
    init(
        inputLoader: InputLoaderProtocol = InputLoader(),
        searchEngine: SearchEngineProtocol = SearchEngine(),
        outputWriter: OutputWriterProtocol = StandardOutputWriter()
    ) {
        self.inputLoader = inputLoader
        self.searchEngine = searchEngine
        self.outputWriter = outputWriter
        super.init()
    }

    // MARK: - Application Lifecycle
    
    /// Sets up the application window and UI components
    /// - Parameter notification: The launch notification
    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenSize = NSScreen.main!.frame
        let width: CGFloat = 680
        let itemHeight: CGFloat = 44
        let maxVisibleItems: CGFloat = 6
        let searchHeight: CGFloat = 52
        let borderRadius: CGFloat = 10

        // Calculate fixed height based on maximum visible items
        let height = searchHeight + (itemHeight * maxVisibleItems)

        // Create window with native styling
        window = KeyableWindow(
            contentRect: NSRect(x: (screenSize.width - width) / 2,
                                y: (screenSize.height - height) / 2 + 100,  // Slightly above center like Spotlight
                                width: width,
                                height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )

        // Click outside to dismiss
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation
            if !self.window.frame.contains(screenPoint) {
                NSApp.terminate(nil)
            }
        }

        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hidesOnDeactivate = false
        window.appearance = nil  // Inherit system light/dark mode

        // Prevent dock icon
        NSApp.setActivationPolicy(.accessory)

        // Use NSVisualEffectView as the main content - native macOS blur like Spotlight
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffectView.material = .sidebar  // Light with blur in light mode
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = borderRadius
        visualEffectView.layer?.masksToBounds = true
        window.contentView = visualEffectView
        containerView = visualEffectView

        // Search field area
        let sidePadding: CGFloat = 12
        let searchAreaY = height - searchHeight
        let fontSize: CGFloat = 18
        let textFieldHeight: CGFloat = 20  // Approximate height for font size 18

        // Search icon - centered vertically
        let iconSize: CGFloat = 24
        let searchIcon = NSImageView(frame: NSRect(x: sidePadding,
                                                   y: searchAreaY + (searchHeight - iconSize) / 2,
                                                   width: iconSize,
                                                   height: iconSize))
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(symbolConfig)
        searchIcon.contentTintColor = NSColor.secondaryLabelColor
        containerView.addSubview(searchIcon)

        // Search field - sized to text height and centered vertically
        let searchFieldY = searchAreaY + (searchHeight - textFieldHeight) / 2
        searchField = NSSearchField(frame: NSRect(x: sidePadding + 28,
                                                  y: searchFieldY,
                                                  width: width - sidePadding * 2 - 28,
                                                  height: textFieldHeight))
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        searchField.textColor = NSColor.labelColor
        searchField.drawsBackground = false
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.placeholderString = "Search..."

        // Hide the built-in search/cancel buttons
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchButtonCell = nil
            cell.cancelButtonCell = nil
        }

        containerView.addSubview(searchField)

        // Separator line
        let separator = NSBox(frame: NSRect(x: 0, y: height - searchHeight, width: width, height: 1))
        separator.boxType = .separator
        containerView.addSubview(separator)

        // Table view
        let tableHeight = height - searchHeight
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: tableHeight))
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
            if event.keyCode == 126 || // Up arrow
               (event.modifierFlags.contains(.control) && event.keyCode == 35) { // Ctrl + P
                self.moveSelection(offset: -1)
                return nil
            }
            
            if event.keyCode == 125 || // Down arrow
               (event.modifierFlags.contains(.control) && event.keyCode == 45) { // Ctrl + N
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

        // Add loading
        loadingLabel = NSTextField(labelWithString: "")
        loadingLabel?.textColor = NSColor.secondaryLabelColor
        loadingLabel?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        loadingLabel?.alignment = .center
        loadingLabel?.frame = NSRect(x: 0, y: tableHeight / 2, width: width, height: 20)
        containerView.addSubview(loadingLabel!)

        // Load input asynchronously using the injected loader
        inputLoader.loadAsync { [weak self] result in
            guard let self = self else { return }

            // Remove loading indicator
            self.loadingLabel?.removeFromSuperview()
            self.loadingLabel = nil

            switch result {
            case .success(let rawItems):
                // Convert to SearchableItem with pre-computed lowercase
                self.allItems = rawItems.map { SearchableItem($0) }
                self.filteredItems = self.allItems
                self.tableView.reloadData()
                self.selectRow(index: 0)

            case .failure(let error):
                switch error {
                case .isTerminal:
                    print("Error: No input provided. Please pipe some input into mac-menu.")
                    print("Use 'mac-menu --help' to learn more about how to use the program.")
                case .noInput:
                    print("Error: No input provided. Please pipe some input into mac-menu.")
                    print("Use 'mac-menu --help' to learn more about how to use the program.")
                case .readError:
                    print("Error: Failed to read input.")
                }
                NSApp.terminate(nil)
            }
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
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let container = NSView()

        let textField = NSTextField(labelWithString: filteredItems[row].original)
        textField.textColor = NSColor.labelColor
        textField.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        textField.lineBreakMode = .byTruncatingTail
        textField.isBordered = false
        textField.drawsBackground = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(textField)

        // Use Auto Layout to center vertically
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

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
        return 48 // Consistent row height
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
    /// Uses debouncing to avoid excessive filtering during rapid typing
    /// - Parameter obj: The notification object
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }

        // Cancel any pending search
        searchDebounceTimer?.invalidate()

        // Debounce for 50ms to reduce CPU usage during rapid typing
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.performSearch(query: searchField.stringValue)
        }
    }

    /// Performs the actual search/filter operation using the injected search engine
    /// - Parameter query: The search query string
    private func performSearch(query: String) {
        // Use the search engine to perform fuzzy matching
        let results = searchEngine.search(query: query, in: allItems)
        filteredItems = results.map { $0.item }

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
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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
        outputWriter.write(filteredItems[row].original)
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

private let helpFlags: Set<String>     = ["-h", "--help", "help"]
private let versionFlags: Set<String>  = ["-v", "--version", "version"]

private func handleEarlyFlags() {
    let args = Set(CommandLine.arguments.dropFirst())

    if !helpFlags.isDisjoint(with: args) {
        print("""
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
        print("mac-menu: \(appVersion)")
        exit(EXIT_SUCCESS)
    }
}

handleEarlyFlags()

// Start app
let app = NSApplication.shared
let delegate = MenuApp()
app.delegate = delegate
app.run()
