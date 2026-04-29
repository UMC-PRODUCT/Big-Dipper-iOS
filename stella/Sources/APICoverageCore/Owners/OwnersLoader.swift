import Foundation
import Yams

public struct Owners: Sendable, Equatable {
    public static let empty = Owners(tagOwners: [:], endpointOwners: [:])

    public let tagOwners: [String: String]
    public let endpointOwners: [OpenAPIKey: String]

    public init(tagOwners: [String: String], endpointOwners: [OpenAPIKey: String]) {
        self.tagOwners = tagOwners
        self.endpointOwners = endpointOwners
    }

    public func email(for key: OpenAPIKey, tag: String?) -> String? {
        if let direct = endpointOwners[key] { return direct }
        if let tag, let viaTag = tagOwners[tag] { return viaTag }
        return nil
    }
}

public enum OwnersLoader {
    public static func serialize(_ owners: Owners) -> String {
        if owners.tagOwners.isEmpty && owners.endpointOwners.isEmpty {
            return "owners: {}\n"
        }

        var lines: [String] = ["owners:"]

        let sortedTags = owners.tagOwners.sorted { $0.key < $1.key }
        if !sortedTags.isEmpty {
            lines.append("  tags:")
            for (tag, email) in sortedTags {
                lines.append("    \(yamlScalar(tag)): \(yamlScalar(email))")
            }
        }

        let sortedEndpoints = owners.endpointOwners.sorted {
            if $0.key.path != $1.key.path { return $0.key.path < $1.key.path }
            return $0.key.method.rawValue < $1.key.method.rawValue
        }
        if !sortedEndpoints.isEmpty {
            lines.append("  endpoints:")
            for (key, email) in sortedEndpoints {
                lines.append("    - method: \(key.method.rawValue)")
                lines.append("      path: \(yamlScalar(key.path))")
                lines.append("      owner: \(yamlScalar(email))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func yamlScalar(_ s: String) -> String {
        let needsQuote = s.isEmpty
            || s.contains(":")
            || s.contains("#")
            || s.contains("\"")
            || s.contains("'")
            || s.contains("[")
            || s.contains("]")
            || s.contains("{")
            || s.contains("}")
            || s.contains(",")
            || s.contains("&")
            || s.contains("*")
            || s.first?.isWhitespace == true
        if needsQuote {
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return s
    }

    public static func parse(_ yaml: String) throws -> Owners {
        guard let root = try Yams.load(yaml: yaml) as? [String: Any],
              let owners = root["owners"] as? [String: Any]
        else {
            return .empty
        }

        let tagOwners = parseTagOwners(owners["tags"])
        let endpointOwners = try parseEndpointOwners(owners["endpoints"])

        return Owners(tagOwners: tagOwners, endpointOwners: endpointOwners)
    }

    public static func load(from url: URL) throws -> Owners {
        try parse(String(contentsOf: url, encoding: .utf8))
    }

    private static func parseTagOwners(_ raw: Any?) -> [String: String] {
        guard let dict = raw as? [String: Any] else { return [:] }
        return dict.compactMapValues { $0 as? String }
    }

    private static func parseEndpointOwners(_ raw: Any?) throws -> [OpenAPIKey: String] {
        guard let list = raw as? [[String: Any]] else { return [:] }

        var result: [OpenAPIKey: String] = [:]
        for entry in list {
            guard let methodString = entry["method"] as? String,
                  let path = entry["path"] as? String,
                  let owner = entry["owner"] as? String
            else {
                throw APICoverageError.invalidYAML(
                    "owners.endpoints entry requires method, path, owner"
                )
            }
            guard let method = HTTPMethod(rawValue: methodString.uppercased()) else {
                throw APICoverageError.invalidYAML("unsupported HTTP method: \(methodString)")
            }
            result[OpenAPIKey(method: method, path: path)] = owner
        }
        return result
    }
}
