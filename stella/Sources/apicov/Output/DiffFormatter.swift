import APICoverageCore
import Foundation

struct CoverageDiff: Sendable {
    let newlyConnected: [(project: String, key: OpenAPIKey)]
    let newlyDisconnected: [(project: String, key: OpenAPIKey)]
    let summaryDelta: [String: (matched: Int, missing: Int)]
}

enum DiffFormatter {
    static func compute(old: CoverageSnapshot, new: CoverageSnapshot) -> CoverageDiff {
        var newlyConnected: [(project: String, key: OpenAPIKey)] = []
        var newlyDisconnected: [(project: String, key: OpenAPIKey)] = []
        let oldEndpointsByKey = Dictionary(uniqueKeysWithValues: old.endpoints.map { ($0.key, $0) })

        for newEntry in new.endpoints {
            let oldEntry = oldEndpointsByKey[newEntry.key]
            for (project, connection) in newEntry.connections {
                let oldConnection = oldEntry?.connections[project] ?? nil
                switch (oldConnection, connection) {
                case (nil, .some):
                    newlyConnected.append((project: project, key: newEntry.key))
                case (.some, nil):
                    newlyDisconnected.append((project: project, key: newEntry.key))
                default:
                    break
                }
            }
        }

        let projects = Set(old.summary.keys).union(new.summary.keys)
        let summaryDelta = projects.reduce(into: [String: (matched: Int, missing: Int)]()) { result, project in
            result[project] = (
                matched: (new.summary[project]?.matched ?? 0) - (old.summary[project]?.matched ?? 0),
                missing: (new.summary[project]?.missing ?? 0) - (old.summary[project]?.missing ?? 0)
            )
        }

        return CoverageDiff(
            newlyConnected: newlyConnected,
            newlyDisconnected: newlyDisconnected,
            summaryDelta: summaryDelta
        )
    }

    static func format(_ diff: CoverageDiff) -> String {
        var lines: [String] = ["== Summary delta =="]

        for (project, delta) in diff.summaryDelta.sorted(by: { $0.key < $1.key }) {
            lines.append(
                "  \(project): matched \(formatSigned(delta.matched)), missing \(formatSigned(delta.missing))"
            )
        }

        if !diff.newlyConnected.isEmpty {
            lines.append("")
            lines.append("== Newly connected ==")
            for (project, key) in sorted(diff.newlyConnected) {
                lines.append("  + [\(project)] \(key.method.rawValue) \(key.path)")
            }
        }

        if !diff.newlyDisconnected.isEmpty {
            lines.append("")
            lines.append("== Newly disconnected ==")
            for (project, key) in sorted(diff.newlyDisconnected) {
                lines.append("  - [\(project)] \(key.method.rawValue) \(key.path)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func sorted(
        _ values: [(project: String, key: OpenAPIKey)]
    ) -> [(project: String, key: OpenAPIKey)] {
        values.sorted {
            if $0.project != $1.project {
                return $0.project < $1.project
            }
            if $0.key.path != $1.key.path {
                return $0.key.path < $1.key.path
            }
            return $0.key.method.rawValue < $1.key.method.rawValue
        }
    }

    private static func formatSigned(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
