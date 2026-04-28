import Foundation

public enum HTTPMethod: String, Codable, Hashable, Sendable, CaseIterable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

public struct OpenAPIKey: Hashable, Codable, Sendable {
    public let method: HTTPMethod
    public let path: String

    public init(method: HTTPMethod, path: String) {
        self.method = method
        self.path = path
    }
}

public struct OpenAPIOperation: Codable, Sendable, Equatable {
    public let key: OpenAPIKey
    public let tag: String?
    public let operationId: String?
    public let summary: String?
}

public struct OpenAPIDocument: Codable, Sendable, Equatable {
    public let title: String
    public let version: String
    public let operations: [OpenAPIOperation]

    public var operationsByKey: [OpenAPIKey: OpenAPIOperation] {
        Dictionary(uniqueKeysWithValues: operations.map { ($0.key, $0) })
    }
}
