import Foundation
import Yams

public struct AuthorMapper: Sendable {
    public static let empty = AuthorMapper(entries: [])

    private struct Entry: Sendable {
        let email: String
        let displayName: String
        let github: String?
    }

    private let entries: [Entry]

    private init(entries: [Entry]) {
        self.entries = entries
    }

    public static func parse(_ yaml: String) throws -> AuthorMapper {
        guard let root = try Yams.load(yaml: yaml) as? [String: Any] else {
            return AuthorMapper(entries: [])
        }

        let rawEntries = (root["authors"] as? [[String: Any]]) ?? []
        let entries = rawEntries.compactMap { dictionary -> Entry? in
            guard let email = dictionary["email"] as? String,
                  let displayName = dictionary["displayName"] as? String
            else {
                return nil
            }

            return Entry(
                email: email,
                displayName: displayName,
                github: dictionary["github"] as? String
            )
        }

        return AuthorMapper(entries: entries)
    }

    public static func load(from url: URL) throws -> AuthorMapper {
        try parse(String(contentsOf: url, encoding: .utf8))
    }

    public func author(for blame: BlameInfo) -> AuthorRef {
        if let entry = entries.first(where: { entry in
            entry.email.caseInsensitiveCompare(blame.email) == .orderedSame
        }) {
            return AuthorRef(
                email: blame.email,
                name: blame.name,
                displayName: entry.displayName,
                githubUsername: entry.github
            )
        }

        return AuthorRef(
            email: blame.email,
            name: blame.name,
            displayName: blame.name,
            githubUsername: nil
        )
    }

    public func author(forEmail email: String) -> AuthorRef {
        if let entry = entries.first(where: { entry in
            entry.email.caseInsensitiveCompare(email) == .orderedSame
        }) {
            return AuthorRef(
                email: entry.email,
                name: entry.displayName,
                displayName: entry.displayName,
                githubUsername: entry.github
            )
        }

        return AuthorRef(
            email: email,
            name: email,
            displayName: email,
            githubUsername: nil
        )
    }
}
