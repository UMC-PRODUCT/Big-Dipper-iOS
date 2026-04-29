import Foundation

public struct RouterCase: Sendable, Equatable, Codable {
    public let routerEnum: String
    public let caseName: String
    public let filePath: String
    public let line: Int
    public let pathArm: String?
    public let methodArm: String?
    public let summary: String?

    public init(
        routerEnum: String,
        caseName: String,
        filePath: String,
        line: Int,
        pathArm: String?,
        methodArm: String?,
        summary: String?
    ) {
        self.routerEnum = routerEnum
        self.caseName = caseName
        self.filePath = filePath
        self.line = line
        self.pathArm = pathArm
        self.methodArm = methodArm
        self.summary = summary
    }
}
