import Foundation

public struct BlameInfo: Sendable, Equatable {
    public let email: String
    public let name: String
    public let commitSHA: String
    public let date: Date

    public init(email: String, name: String, commitSHA: String, date: Date) {
        self.email = email
        self.name = name
        self.commitSHA = commitSHA
        self.date = date
    }
}

public struct AuthorRef: Sendable, Equatable, Codable {
    public let email: String
    public let name: String
    public let displayName: String
    public let githubUsername: String?

    public init(email: String, name: String, displayName: String, githubUsername: String?) {
        self.email = email
        self.name = name
        self.displayName = displayName
        self.githubUsername = githubUsername
    }
}
