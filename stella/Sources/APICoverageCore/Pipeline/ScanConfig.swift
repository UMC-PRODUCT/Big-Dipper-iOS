import Foundation

public struct ProjectInput: Sendable {
    public let key: String
    public let displayName: String
    public let rootPath: URL
    public let routerGlobs: [String]

    public init(key: String, displayName: String, rootPath: URL, routerGlobs: [String]) {
        self.key = key
        self.displayName = displayName
        self.rootPath = rootPath
        self.routerGlobs = routerGlobs
    }

    public static func appProduct(rootPath: URL) -> ProjectInput {
        ProjectInput(
            key: "appProduct",
            displayName: "AppProduct",
            rootPath: rootPath,
            routerGlobs: ["**/Router/*Router.swift"]
        )
    }

    public static func umcApp(rootPath: URL) -> ProjectInput {
        ProjectInput(
            key: "umcApp",
            displayName: "UMCApp",
            rootPath: rootPath,
            routerGlobs: ["**/Data/Sources/*Router.swift"]
        )
    }
}

public struct ScanConfig: Sendable {
    public let openAPISource: OpenAPISource
    public let projects: [ProjectInput]
    public let overridesURL: URL?
    public let authorsURL: URL?
    public let ownersURL: URL?
    public let blameRoot: URL

    public init(
        openAPISource: OpenAPISource,
        projects: [ProjectInput],
        overridesURL: URL?,
        authorsURL: URL?,
        ownersURL: URL? = nil,
        blameRoot: URL
    ) {
        self.openAPISource = openAPISource
        self.projects = projects
        self.overridesURL = overridesURL
        self.authorsURL = authorsURL
        self.ownersURL = ownersURL
        self.blameRoot = blameRoot
    }
}
