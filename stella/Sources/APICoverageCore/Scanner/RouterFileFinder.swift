import Foundation

public struct RouterFileFinder: Sendable {
    public init() {}

    /// Supports a small glob subset: `**` for nested directories and `*` for a single path component.
    public func find(in root: URL, patterns: [String]) throws -> [URL] {
        let regexes = patterns.map(Self.regex(forGlob:))
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = Self.relativePath(for: url, root: root)
            if regexes.contains(where: { relativePath.range(of: $0, options: .regularExpression) != nil }) {
                results.append(url)
            }
        }

        return results.sorted { $0.path < $1.path }
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard urlPath.hasPrefix(prefix) else {
            return url.lastPathComponent
        }
        return String(urlPath.dropFirst(prefix.count))
    }

    private static func regex(forGlob pattern: String) -> String {
        var output = "^"
        var index = pattern.startIndex

        while index < pattern.endIndex {
            if pattern[index...].hasPrefix("**") {
                output += ".*"
                index = pattern.index(index, offsetBy: 2)
                continue
            }

            let character = pattern[index]
            switch character {
            case "*":
                output += "[^/]*"
            case "+", ".", "(", ")", "[", "]", "{", "}", "|", "^", "$", "\\":
                output += "\\\(character)"
            default:
                output.append(character)
            }
            index = pattern.index(after: index)
        }

        output += "$"
        return output
    }
}
