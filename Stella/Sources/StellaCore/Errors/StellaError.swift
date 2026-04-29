import Foundation

public enum StellaError: Error, Equatable {
    case openAPIHTTPStatus(Int)
    case openAPINetwork(String)
    case fileNotFound(String)
    case invalidYAML(String)
    case scannerError(file: String, reason: String)
    case blameFailed(file: String, reason: String)
}
