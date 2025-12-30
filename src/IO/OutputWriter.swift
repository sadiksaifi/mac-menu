import Foundation

// Note: When compiled via SPM, import MacMenuCore
// When compiled via swiftc (Makefile), all files are in one module

/// Writes output to stdout
public final class StandardOutputWriter: OutputWriterProtocol {

    public init() {}

    /// Writes a string to stdout
    /// - Parameter string: The string to write
    public func write(_ string: String) {
        print(string)
        fflush(stdout)
    }
}
