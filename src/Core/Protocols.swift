import Foundation

// Note: When compiled via SPM, import MacMenuModels
// When compiled via swiftc (Makefile), all files are in one module

/// Result of a search operation
public struct SearchResult {
    public let item: SearchableItem
    public let score: Int
    public let positions: [Int]

    public init(item: SearchableItem, score: Int, positions: [Int]) {
        self.item = item
        self.score = score
        self.positions = positions
    }
}

/// Protocol for search functionality - allows for dependency injection and testing
public protocol SearchEngineProtocol {
    /// Performs a fuzzy search on the given items
    /// - Parameters:
    ///   - query: The search query string
    ///   - items: The items to search through
    /// - Returns: Filtered and sorted search results
    func search(query: String, in items: [SearchableItem]) -> [SearchResult]
}

/// Error types for input loading
public enum InputError: Error, Equatable {
    case noInput
    case isTerminal
    case readError
}

/// Protocol for input loading - allows for dependency injection and testing
public protocol InputLoaderProtocol {
    /// Loads input asynchronously
    /// - Parameter completion: Callback with the result (success with items or failure with error)
    func loadAsync(completion: @escaping (Result<[String], InputError>) -> Void)
}

/// Protocol for output writing - allows for dependency injection and testing
public protocol OutputWriterProtocol {
    /// Writes a string to the output
    /// - Parameter string: The string to write
    func write(_ string: String)
}
