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
    public let description: String?
    public let parameters: [OpenAPIParameter]
    public let requestBody: String?
    public let requestBodyExample: String?
    public let responses: [OpenAPIResponse]

    public init(
        key: OpenAPIKey,
        tag: String?,
        operationId: String?,
        summary: String?,
        description: String? = nil,
        parameters: [OpenAPIParameter] = [],
        requestBody: String? = nil,
        requestBodyExample: String? = nil,
        responses: [OpenAPIResponse] = []
    ) {
        self.key = key
        self.tag = tag
        self.operationId = operationId
        self.summary = summary
        self.description = description
        self.parameters = parameters
        self.requestBody = requestBody
        self.requestBodyExample = requestBodyExample
        self.responses = responses
    }
}

public struct OpenAPIParameter: Codable, Sendable, Equatable {
    public let name: String
    public let location: String
    public let required: Bool
    public let description: String?
    public let schema: String?

    public init(name: String, location: String, required: Bool, description: String?, schema: String?) {
        self.name = name
        self.location = location
        self.required = required
        self.description = description
        self.schema = schema
    }
}

public struct OpenAPIResponse: Codable, Sendable, Equatable {
    public let statusCode: String
    public let description: String?

    public init(statusCode: String, description: String?) {
        self.statusCode = statusCode
        self.description = description
    }
}

public struct OpenAPIDocument: Codable, Sendable, Equatable {
    public let title: String
    public let version: String
    public let operations: [OpenAPIOperation]

    public var operationsByKey: [OpenAPIKey: OpenAPIOperation] {
        Dictionary(uniqueKeysWithValues: operations.map { ($0.key, $0) })
    }
}
