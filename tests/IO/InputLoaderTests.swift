import Testing
import Foundation
@testable import MacMenuLib

struct InputLoaderTests {
    @Test func loadsLinesFromPipe() async throws {
        // Create pipe with test data
        let pipe = Pipe()
        let testData = "line1\nline2\nline3\n"
        pipe.fileHandleForWriting.write(testData.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()

        let loader = InputLoader(fileHandle: pipe.fileHandleForReading)

        await withCheckedContinuation { continuation in
            loader.loadAsync { result in
                switch result {
                case .success(let items):
                    #expect(items == ["line1", "line2", "line3"])
                case .failure:
                    Issue.record("Expected success")
                }
                continuation.resume()
            }
        }
    }

    @Test func handlesEmptyInput() async {
        let pipe = Pipe()
        pipe.fileHandleForWriting.closeFile()

        let loader = InputLoader(fileHandle: pipe.fileHandleForReading)

        await withCheckedContinuation { continuation in
            loader.loadAsync { result in
                switch result {
                case .success:
                    Issue.record("Expected failure for empty input")
                case .failure(let error):
                    #expect(error == .noInput)
                }
                continuation.resume()
            }
        }
    }

    @Test func filtersEmptyLines() async throws {
        let pipe = Pipe()
        let testData = "line1\n\nline2\n\n\nline3\n"
        pipe.fileHandleForWriting.write(testData.data(using: .utf8)!)
        pipe.fileHandleForWriting.closeFile()

        let loader = InputLoader(fileHandle: pipe.fileHandleForReading)

        await withCheckedContinuation { continuation in
            loader.loadAsync { result in
                switch result {
                case .success(let items):
                    #expect(items == ["line1", "line2", "line3"], "Empty lines should be filtered")
                case .failure:
                    Issue.record("Expected success")
                }
                continuation.resume()
            }
        }
    }
}
