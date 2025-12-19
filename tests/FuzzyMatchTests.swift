import Testing
@testable import FuzzyMatchModule

struct FuzzyMatchTests {
    @Test func emptyPatternMatchesEverything() throws {
        let (matched, result) = fuzzyMatch(pattern: "", string: "Hello World")
        #expect(matched, "Empty pattern should match any string")
        #expect(result != nil, "Result should not be nil for empty pattern")
        #expect(result?.positions.isEmpty == true, "Empty pattern should have no positions")
    }

    @Test func patternLongerThanStringDoesNotMatch() throws {
        let (matched, result) = fuzzyMatch(pattern: "toolong", string: "tiny")
        #expect(!matched, "Longer pattern should not match shorter string")
        #expect(result == nil, "Result should be nil when there is no match")
    }

    @Test func exactMatchProducesSequentialPositions() throws {
        let (matched, result) = fuzzyMatch(pattern: "abc", string: "abc")
        #expect(matched, "Exact match should succeed")
        #expect(result?.positions == [0, 1, 2], "Exact match should return sequential positions")
        #expect((result?.score ?? 0) > 0, "Exact match should have a positive score")
    }

    @Test func caseInsensitiveMatching() throws {
        let (matched, result) = fuzzyMatch(pattern: "FZ", string: "fuzzy")
        #expect(matched, "Matching should be case-insensitive")
        #expect(result?.positions == [0, 3], "Expected positions for 'FZ' in 'fuzzy' to be [0, 3]")
    }
}
