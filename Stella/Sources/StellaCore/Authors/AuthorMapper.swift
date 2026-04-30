import Foundation
import Yams

public struct AuthorMappingEntry: Sendable, Equatable, Codable, Hashable {
    public let email: String
    public let displayName: String
    public let github: String?

    public init(email: String, displayName: String, github: String?) {
        self.email = email
        self.displayName = displayName
        self.github = github
    }
}

public struct AuthorMapper: Sendable {
    public static let empty = AuthorMapper(entries: [])

    public let entries: [AuthorMappingEntry]

    public init(entries: [AuthorMappingEntry]) {
        self.entries = entries
    }

    public static func parse(_ yaml: String) throws -> AuthorMapper {
        guard let root = try Yams.load(yaml: yaml) as? [String: Any] else {
            return AuthorMapper(entries: [])
        }

        let rawEntries = (root["authors"] as? [[String: Any]]) ?? []
        let entries = rawEntries.compactMap { dictionary -> AuthorMappingEntry? in
            guard let email = dictionary["email"] as? String,
                  let displayName = dictionary["displayName"] as? String
            else {
                return nil
            }

            return AuthorMappingEntry(
                email: email,
                displayName: displayName,
                github: dictionary["github"] as? String
            )
        }

        return AuthorMapper(entries: entries)
    }

    public static func serialize(_ entries: [AuthorMappingEntry]) -> String {
        guard !entries.isEmpty else { return "authors: []\n" }

        var lines = ["authors:"]
        for entry in entries.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) {
            lines.append("  - email: \(yamlScalar(entry.email))")
            lines.append("    displayName: \(yamlScalar(entry.displayName))")
            if let github = entry.github, !github.isEmpty {
                lines.append("    github: \(yamlScalar(github))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
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

    private static func yamlScalar(_ s: String) -> String {
        let needsQuotes = s.isEmpty
            || s.contains(":")
            || s.contains("#")
            || s.contains("{")
            || s.contains("}")
            || s.contains("[")
            || s.contains("]")
            || s.contains(",")
            || s.contains("\n")
            || s.trimmingCharacters(in: .whitespacesAndNewlines) != s

        if needsQuotes {
            return "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return s
    }
}
