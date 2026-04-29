import Foundation

public struct CoverageSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let openAPI: OpenAPISummary
    public let projects: [ProjectInfo]
    public let endpoints: [EndpointEntry]
    public let unmatchedRouterCases: [UnmatchedEntry]
    public let summary: [String: ProjectStats]

    public init(
        schemaVersion: Int,
        generatedAt: Date,
        openAPI: OpenAPISummary,
        projects: [ProjectInfo],
        endpoints: [EndpointEntry],
        unmatchedRouterCases: [UnmatchedEntry],
        summary: [String: ProjectStats]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.openAPI = openAPI
        self.projects = projects
        self.endpoints = endpoints
        self.unmatchedRouterCases = unmatchedRouterCases
        self.summary = summary
    }

    public struct OpenAPISummary: Codable, Sendable, Equatable {
        public let title: String
        public let version: String
        public let totalPaths: Int

        public init(title: String, version: String, totalPaths: Int) {
            self.title = title
            self.version = version
            self.totalPaths = totalPaths
        }
    }

    public struct ProjectInfo: Codable, Sendable, Equatable {
        public let key: String
        public let displayName: String
        public let rootPath: String

        public init(key: String, displayName: String, rootPath: String) {
            self.key = key
            self.displayName = displayName
            self.rootPath = rootPath
        }
    }

    public struct EndpointEntry: Codable, Sendable, Equatable {
        public let key: OpenAPIKey
        public let tag: String?
        public let operationId: String?
        public let summary: String?
        public let description: String?
        public let parameters: [OpenAPIParameter]
        public let requestBody: String?
        public let requestBodyExample: String?
        public let responses: [OpenAPIResponse]
        public let owner: AuthorRef?
        public let connections: [String: Connection?]

        public init(
            key: OpenAPIKey,
            tag: String?,
            operationId: String?,
            summary: String?,
            description: String? = nil,
            parameters: [OpenAPIParameter] = [],
            requestBody: String? = nil,
            requestBodyExample: String? = nil,
            responses: [OpenAPIResponse] = [],
            owner: AuthorRef? = nil,
            connections: [String: Connection?]
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
            self.owner = owner
            self.connections = connections
        }

        enum CodingKeys: String, CodingKey {
            case key, tag, operationId, summary, description, parameters, requestBody, requestBodyExample, responses, owner, connections
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try container.decode(OpenAPIKey.self, forKey: .key)
            tag = try container.decodeIfPresent(String.self, forKey: .tag)
            operationId = try container.decodeIfPresent(String.self, forKey: .operationId)
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            parameters = try container.decodeIfPresent([OpenAPIParameter].self, forKey: .parameters) ?? []
            requestBody = try container.decodeIfPresent(String.self, forKey: .requestBody)
            requestBodyExample = try container.decodeIfPresent(String.self, forKey: .requestBodyExample)
            responses = try container.decodeIfPresent([OpenAPIResponse].self, forKey: .responses) ?? []
            owner = try container.decodeIfPresent(AuthorRef.self, forKey: .owner)
            connections = try container.decode([String: Connection?].self, forKey: .connections)
        }
    }

    public struct Connection: Codable, Sendable, Equatable {
        public let routerEnum: String
        public let caseName: String
        public let filePath: String
        public let line: Int
        public let author: AuthorRef
        public let lastCommitSHA: String
        public let lastCommitDate: Date

        public init(
            routerEnum: String,
            caseName: String,
            filePath: String,
            line: Int,
            author: AuthorRef,
            lastCommitSHA: String,
            lastCommitDate: Date
        ) {
            self.routerEnum = routerEnum
            self.caseName = caseName
            self.filePath = filePath
            self.line = line
            self.author = author
            self.lastCommitSHA = lastCommitSHA
            self.lastCommitDate = lastCommitDate
        }
    }

    public struct UnmatchedEntry: Codable, Sendable, Equatable {
        public let project: String
        public let routerEnum: String
        public let caseName: String
        public let filePath: String
        public let line: Int
        public let reason: String

        public init(
            project: String,
            routerEnum: String,
            caseName: String,
            filePath: String,
            line: Int,
            reason: String
        ) {
            self.project = project
            self.routerEnum = routerEnum
            self.caseName = caseName
            self.filePath = filePath
            self.line = line
            self.reason = reason
        }
    }

    public struct ProjectStats: Codable, Sendable, Equatable {
        public let matched: Int
        public let missing: Int
        public let unmatched: Int

        public init(matched: Int, missing: Int, unmatched: Int) {
            self.matched = matched
            self.missing = missing
            self.unmatched = unmatched
        }
    }
}
