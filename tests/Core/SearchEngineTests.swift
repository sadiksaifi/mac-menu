import Testing
@testable import MacMenuLib

struct SearchEngineTests {
    let engine = SearchEngine()

    @Test func emptyQueryReturnsAllItems() {
        let items = [
            SearchableItem("Apple"),
            SearchableItem("Banana"),
            SearchableItem("Cherry")
        ]
        let results = engine.search(query: "", in: items)
        #expect(results.count == 3, "Empty query should return all items")
    }

    @Test func queryFiltersResults() {
        let items = [
            SearchableItem("Apple"),
            SearchableItem("Banana"),
            SearchableItem("Apricot")
        ]
        let results = engine.search(query: "ap", in: items)
        // Fuzzy matching may match more items, but Apple and Apricot should score highest
        #expect(results.count >= 2, "Should match at least Apple and Apricot")
        let topTwo = results.prefix(2).map { $0.item.original }
        #expect(topTwo.contains("Apple") || topTwo.contains("Apricot"), "Top results should include Apple or Apricot")
    }

    @Test func resultsSortedByScore() {
        let items = [
            SearchableItem("application"),
            SearchableItem("apple"),
            SearchableItem("app")
        ]
        let results = engine.search(query: "app", in: items)
        // Exact match or shorter match should score higher
        #expect(results.first?.item.original == "app", "Exact match should be first")
    }

    @Test func noMatchReturnsEmpty() {
        let items = [
            SearchableItem("Hello"),
            SearchableItem("World")
        ]
        let results = engine.search(query: "xyz", in: items)
        #expect(results.isEmpty, "No match should return empty array")
    }

    @Test func caseInsensitiveSearch() {
        let items = [SearchableItem("MacMenu")]
        let results = engine.search(query: "macmenu", in: items)
        #expect(results.count == 1, "Case-insensitive search should match")
    }
}
