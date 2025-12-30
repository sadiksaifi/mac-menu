import Foundation

/// Represents a searchable item with cached lowercase for efficient fuzzy matching
public struct SearchableItem {
    /// The original string value
    public let original: String
    /// Pre-computed lowercase version for efficient comparison
    public let lowercased: String

    public init(_ string: String) {
        self.original = string
        self.lowercased = string.lowercased()
    }
}
