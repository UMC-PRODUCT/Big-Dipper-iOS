import Foundation
import Yams

public struct Overrides: Sendable, Equatable {
    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public struct Entry: Sendable, Equatable {
        public let routerEnum: String
        public let caseName: String
        public let target: Target

        public init(routerEnum: String, caseName: String, target: Target) {
            self.routerEnum = routerEnum
            self.caseName = caseName
            self.target = target
        }
    }

    public enum Target: Sendable, Equatable {
        case remap(OpenAPIKey)
        case ignore(reason: String)
    }

    public func entry(for routerCase: RouterCase) -> Entry? {
        entries.first {
            $0.routerEnum == routerCase.routerEnum && $0.caseName == routerCase.caseName
        }
    }
}

public enum OverridesLoader {
    public static func parse(_ yaml: String) throws -> Overrides {
        guard let root = try Yams.load(yaml: yaml) as? [String: Any],
              let rawEntries = root["overrides"] as? [[String: Any]]
        else {
            return Overrides(entries: [])
        }

        var entries: [Overrides.Entry] = []
        for rawEntry in rawEntries {
            let routerCase = try parseRouterCase(rawEntry)

            if let ignore = rawEntry["ignore"] as? Bool, ignore {
                let reason = rawEntry["reason"] as? String ?? "ignored"
                entries.append(Overrides.Entry(
                    routerEnum: routerCase.routerEnum,
                    caseName: routerCase.caseName,
                    target: .ignore(reason: reason)
                ))
                continue
            }

            if let openAPIKey = try parseOpenAPIKey(rawEntry) {
                entries.append(Overrides.Entry(
                    routerEnum: routerCase.routerEnum,
                    caseName: routerCase.caseName,
                    target: .remap(openAPIKey)
                ))
                continue
            }

            throw StellaError.invalidYAML(
                "override must have either ignore:true or openAPI:{method,path}"
            )
        }

        return Overrides(entries: entries)
    }

    public static func load(from url: URL) throws -> Overrides {
        try parse(String(contentsOf: url, encoding: .utf8))
    }

    private static func parseRouterCase(_ rawEntry: [String: Any]) throws -> (
        routerEnum: String,
        caseName: String
    ) {
        guard let dotted = rawEntry["routerCase"] as? String else {
            throw StellaError.invalidYAML("missing routerCase")
        }

        let parts = dotted.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw StellaError.invalidYAML("routerCase must be 'Enum.case': \(dotted)")
        }

        return (routerEnum: parts[0], caseName: parts[1])
    }

    private static func parseOpenAPIKey(_ rawEntry: [String: Any]) throws -> OpenAPIKey? {
        guard let openAPI = rawEntry["openAPI"] as? [String: Any] else {
            return nil
        }
        guard let methodString = openAPI["method"] as? String,
              let path = openAPI["path"] as? String
        else {
            throw StellaError.invalidYAML("openAPI override requires method and path")
        }
        guard let method = HTTPMethod(rawValue: methodString.uppercased()) else {
            throw StellaError.invalidYAML("unsupported HTTP method: \(methodString)")
        }

        return OpenAPIKey(method: method, path: path)
    }
}
