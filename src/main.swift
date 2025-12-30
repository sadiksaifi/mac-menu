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
        let width: CGFloat = 720
        let itemHeight: CGFloat = 48
        let maxVisibleItems: CGFloat = 5
        let searchHeight: CGFloat = 57
        let borderRadius: CGFloat = 12
        
        // Calculate fixed height based on maximum visible items
        let height = searchHeight + (itemHeight * maxVisibleItems)

        // Create and configure the main window
        window = NSWindow(
            contentRect: NSRect(x: (screenSize.width - width) / 2,
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
        containerView = NSView(frame: window.contentView!.bounds)
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
            NSColor.white.withAlphaComponent(0.08).cgColor
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
        let searchIcon = NSImageView(frame: NSRect(x: horizontalPadding + 16,
                                                  y: searchFieldY + (searchFieldHeight - 24) / 2,  // Center vertically
                                                  width: 32,
                                                  height: 32))
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(config)
        searchIcon.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        searchIcon.imageScaling = .scaleProportionallyUpOrDown
        containerView.addSubview(searchIcon)
        
        // Configure search field
        searchField = NSSearchField(frame: NSRect(x: horizontalPadding + textPadding + 48, 
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
                .foregroundColor: NSColor.white
            ]
            cell.placeholderAttributedString = NSAttributedString(string: "Search...", attributes: attributes)
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
        let separator = NSView(frame: NSRect(x: horizontalPadding, 
                                           y: height - searchHeight, 
                                           width: width - horizontalPadding * 2, 
                                           height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        containerView.addSubview(separator)

        // Configure table view
        let tableHeight = height - searchHeight
        let sideMargin: CGFloat = 8
        scrollView = NSScrollView(frame: NSRect(x: sideMargin, 
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

        // Add loading indicator
        loadingLabel = NSTextField(labelWithString: "Loading...")
        loadingLabel?.textColor = NSColor.white.withAlphaComponent(0.5)
        loadingLabel?.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        loadingLabel?.alignment = .center
        loadingLabel?.frame = NSRect(x: 0, y: height / 2 - 60, width: width, height: 20)
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
        let cellPadding: CGFloat = 4
        let cell = NSTextField(labelWithString: filteredItems[row].original)
        cell.textColor = NSColor.white
        cell.backgroundColor = NSColor.clear
        cell.isBordered = false
        cell.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        cell.lineBreakMode = .byTruncatingTail
        
        // Create container for proper padding and hover state
        let container = NSView(frame: NSRect(x: 0, y: 0, width: tableView.frame.width, height: tableView.rowHeight))
        container.wantsLayer = true
        
        // Center the cell vertically in its container and add side padding
        let cellHeight = cell.cell?.cellSize.height ?? 20
        let yOffset = (container.frame.height - cellHeight) / 2
        cell.frame = NSRect(x: cellPadding, 
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
