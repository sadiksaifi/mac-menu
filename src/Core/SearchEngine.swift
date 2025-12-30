import Foundation

// Note: When compiled via SPM, import MacMenuModels
// When compiled via swiftc (Makefile), all files are in one module

/// Default implementation of the search engine using fuzzy matching
public final class SearchEngine: SearchEngineProtocol {

    public init() {}

    /// Performs a fuzzy search on the given items
    /// - Parameters:
    ///   - query: The search query string
    ///   - items: The items to search through
    /// - Returns: Filtered and sorted search results
    public func search(query: String, in items: [SearchableItem]) -> [SearchResult] {
        // Empty query returns all items with zero score
        guard !query.isEmpty else {
            return items.map { SearchResult(item: $0, score: 0, positions: []) }
        }

        // Pre-compute lowercased query once
        let lowerQuery = query.lowercased()

        // Perform fuzzy matching on all items
        return items.compactMap { item -> SearchResult? in
            let (matched, result) = fuzzyMatch(
                pattern: lowerQuery,
                string: item.original,
                precomputedLower: item.lowercased
            )
            guard matched, let result = result else { return nil }
            return SearchResult(item: item, score: result.score, positions: result.positions)
        }
        .sorted { $0.score > $1.score }
    }
}
