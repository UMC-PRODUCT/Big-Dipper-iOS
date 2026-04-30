import Foundation
import StellaCore

enum EndpointCopyFormatter {
    static func markdown(
        for entry: CoverageSnapshot.EndpointEntry,
        snapshot: CoverageSnapshot
    ) -> String {
        var lines: [String] = []

        lines.append("# \(entry.key.method.rawValue) \(entry.key.path)")
        lines.append("")
        lines.append("- Summary: \(entry.summary ?? "-")")
        lines.append("- Operation ID: \(entry.operationId ?? "-")")
        lines.append("- Tag: \(entry.tag ?? "-")")
        lines.append("- Owner: \(ownerText(entry.owner))")

        if let description = entry.description, !description.isEmpty {
            lines.append("")
            lines.append("## Description")
            lines.append(description)
        }

        lines.append("")
        lines.append("## Parameters")
        if entry.parameters.isEmpty {
            lines.append("- None")
        } else {
            for parameter in entry.parameters {
                let required = parameter.required ? "required" : "optional"
                let schema = parameter.schema ?? "-"
                let description = parameter.description ?? "-"
                lines.append("- `\(parameter.location)` `\(parameter.name)` (\(schema), \(required)): \(description)")
            }
        }

        lines.append("")
        lines.append("## Request Body")
        if let requestBody = entry.requestBody, !requestBody.isEmpty {
            lines.append(requestBody)
        } else {
            lines.append("- None")
        }

        if let example = entry.requestBodyExample, !example.isEmpty {
            lines.append("")
            lines.append("### Request Example")
            lines.append(codeFence(example))
        }

        lines.append("")
        lines.append("## Responses")
        if entry.responses.isEmpty {
            lines.append("- None")
        } else {
            for response in entry.responses {
                lines.append("### \(response.statusCode) \(response.description ?? "")".trimmingCharacters(in: .whitespaces))
                if let content = response.content, !content.isEmpty {
                    lines.append("- Content: \(content)")
                }
                if let example = response.example, !example.isEmpty {
                    lines.append(codeFence(example))
                }
            }
        }

        lines.append("")
        lines.append("## Connections")
        for project in snapshot.projects {
            let connection = entry.connections[project.key] ?? nil
            if let connection {
                lines.append("- \(project.displayName): \(connection.routerEnum).\(connection.caseName) (`\(connection.filePath):\(connection.line)`, \(connection.author.displayName), \(connection.lastCommitSHA.prefix(7)))")
            } else {
                lines.append("- \(project.displayName): Not connected")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func ownerText(_ owner: AuthorRef?) -> String {
        guard let owner else { return "-" }
        if let github = owner.githubUsername, !github.isEmpty {
            return "\(owner.displayName) (@\(github), \(owner.email))"
        }
        return "\(owner.displayName) (\(owner.email))"
    }

    private static func codeFence(_ text: String) -> String {
        let language = looksLikeJSON(text) ? "json" : ""
        return "```\(language)\n\(text)\n```"
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }
}
