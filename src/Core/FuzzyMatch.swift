import Foundation

/// Result of a fuzzy match attempt including match positions for scoring.
struct FuzzyMatchResult {
    let string: String
    let score: Int
    let positions: [Int]
}

/// Constants used to calculate fuzzy match scores.
private enum ScoreConfig {
    static let bonusMatch: Int = 16
    static let bonusBoundary: Int = 16
    static let bonusConsecutive: Int = 16
    static let penaltyGapStart: Int = -3
    static let penaltyGapExtension: Int = -1
    static let penaltyNonContiguous: Int = -5
}

/// Fuzzy search function implementing fzf's algorithm.
/// - Parameters:
///   - pattern: The search pattern to match (should be pre-lowercased for efficiency)
///   - string: The original string to search in
///   - precomputedLower: Optional pre-computed lowercase version of the string
/// - Returns: A tuple containing whether there's a match and the match result
func fuzzyMatch(pattern: String, string: String, precomputedLower: String? = nil) -> (Bool, FuzzyMatchResult?) {
    // Empty pattern matches everything
    if pattern.isEmpty {
        return (true, FuzzyMatchResult(string: string, score: 0, positions: []))
    }

    // Use pre-computed lowercase if available, otherwise compute it
    let lowerPattern = pattern.lowercased()
    let lowerString = precomputedLower ?? string.lowercased()

    let patternLength = lowerPattern.count
    let stringLength = lowerString.count

    // If pattern is longer than string, no match possible
    if patternLength > stringLength {
        return (false, nil)
    }

    // Convert to arrays for O(1) character access (instead of O(n) String indexing)
    let patternChars = Array(lowerPattern)
    let stringChars = Array(lowerString)

    // Initialize score matrix
    var scores = Array(repeating: Array(repeating: 0, count: stringLength + 1), count: patternLength + 1)
    var positions = Array(repeating: Array(repeating: [Int](), count: stringLength + 1), count: patternLength + 1)

    // Fill score matrix
    for i in 1...patternLength {
        for j in 1...stringLength {
            let patternChar = patternChars[i - 1]
            let stringChar = stringChars[j - 1]

            if patternChar == stringChar {
                var score = ScoreConfig.bonusMatch

                // Bonus for boundary (start of string or after space)
                if j == 1 || stringChars[j - 2] == " " {
                    score += ScoreConfig.bonusBoundary
                }

                // Bonus for consecutive matches
                if i > 1 && j > 1 && patternChars[i - 2] == stringChars[j - 2] {
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
        return (true, FuzzyMatchResult(
            string: string,
            score: finalScore,
            positions: positions[patternLength][stringLength]
        ))
    }

    return (false, nil)
}
