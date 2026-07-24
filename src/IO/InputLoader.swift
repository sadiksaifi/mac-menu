import Foundation
import Darwin

// Note: When compiled via SPM, import MacMenuCore
// When compiled via swiftc (Makefile), all files are in one module

/// Loads input from stdin asynchronously
public final class InputLoader: InputLoaderProtocol {
    private let fileHandle: FileHandle

    public init(fileHandle: FileHandle = .standardInput) {
        self.fileHandle = fileHandle
    }

    /// Loads input asynchronously from stdin
    /// - Parameter completion: Callback with the result (success with items or failure with error)
    public func loadAsync(
        completion: @escaping @MainActor @Sendable (Result<[String], InputError>) -> Void
    ) {
        let fileHandle = fileHandle

        DispatchQueue.global(qos: .userInitiated).async {
            // Check if stdin is a terminal (must be done before reading)
            if isatty(fileHandle.fileDescriptor) != 0 {
                DispatchQueue.main.async {
                    completion(.failure(.isTerminal))
                }
                return
            }

            // Read stdin on background thread (this is the blocking operation)
            guard let data = try? fileHandle.readToEnd(),
                  let input = String(data: data, encoding: .utf8),
                  !input.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(.noInput))
                }
                return
            }

            // Parse items
            let items = input.components(separatedBy: .newlines).filter { !$0.isEmpty }

            DispatchQueue.main.async {
                completion(.success(items))
            }
        }
    }
}
