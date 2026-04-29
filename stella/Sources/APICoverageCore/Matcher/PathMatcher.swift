import Foundation

public struct MatchedRouterCase: Sendable, Equatable {
    public let routerCase: RouterCase
    public let openAPIKey: OpenAPIKey
    public let openAPIOperation: OpenAPIOperation?

    public init(routerCase: RouterCase, openAPIKey: OpenAPIKey, openAPIOperation: OpenAPIOperation?) {
        self.routerCase = routerCase
        self.openAPIKey = openAPIKey
        self.openAPIOperation = openAPIOperation
    }
}

public struct UnmatchedRouterCase: Sendable, Equatable {
    public let routerCase: RouterCase
    public let reason: String

    public init(routerCase: RouterCase, reason: String) {
        self.routerCase = routerCase
        self.reason = reason
    }
}

public struct MatchResult: Sendable, Equatable {
    public let matched: [MatchedRouterCase]
    public let unmatched: [UnmatchedRouterCase]

    public init(matched: [MatchedRouterCase], unmatched: [UnmatchedRouterCase]) {
        self.matched = matched
        self.unmatched = unmatched
    }
}

public struct PathMatcher: Sendable {
    private let openAPI: [OpenAPIKey: OpenAPIOperation]
    private let overrides: Overrides

    public init(openAPI: [OpenAPIKey: OpenAPIOperation], overrides: Overrides) {
        self.openAPI = openAPI
        self.overrides = overrides
    }

    public func match(_ cases: [RouterCase]) -> MatchResult {
        var matched: [MatchedRouterCase] = []
        var unmatched: [UnmatchedRouterCase] = []

        for routerCase in cases {
            if let entry = overrides.entry(for: routerCase) {
                switch entry.target {
                case .ignore(let reason):
                    unmatched.append(UnmatchedRouterCase(
                        routerCase: routerCase,
                        reason: "ignored: \(reason)"
                    ))

                case .remap(let key):
                    matched.append(MatchedRouterCase(
                        routerCase: routerCase,
                        openAPIKey: key,
                        openAPIOperation: openAPI[key]
                    ))
                }
                continue
            }

            guard let pathArm = routerCase.pathArm,
                  let methodArm = routerCase.methodArm,
                  let method = HTTPMethod(rawValue: methodArm.uppercased())
            else {
                unmatched.append(UnmatchedRouterCase(
                    routerCase: routerCase,
                    reason: "missing path or method arm"
                ))
                continue
            }

            let normalizedPath = PathNormalizer.normalize(pathArm)
            let key = OpenAPIKey(method: method, path: normalizedPath)
            if let operation = openAPI[key] {
                matched.append(MatchedRouterCase(
                    routerCase: routerCase,
                    openAPIKey: key,
                    openAPIOperation: operation
                ))
            } else if let templated = templatedMatch(method: method, path: normalizedPath) {
                matched.append(MatchedRouterCase(
                    routerCase: routerCase,
                    openAPIKey: templated.key,
                    openAPIOperation: templated.operation
                ))
            } else {
                unmatched.append(UnmatchedRouterCase(
                    routerCase: routerCase,
                    reason: "no OpenAPI entry for \(method.rawValue) \(normalizedPath)"
                ))
            }
        }

        return MatchResult(matched: matched, unmatched: unmatched)
    }

    private func templatedMatch(
        method: HTTPMethod,
        path: String
    ) -> (key: OpenAPIKey, operation: OpenAPIOperation)? {
        let candidates = openAPI
            .filter { $0.key.method == method && Self.pathsMatchIgnoringParameterNames($0.key.path, path) }
            .sorted {
                if $0.key.path != $1.key.path {
                    return $0.key.path < $1.key.path
                }
                return $0.key.method.rawValue < $1.key.method.rawValue
            }

        guard let first = candidates.first else {
            return nil
        }
        return (key: first.key, operation: first.value)
    }

    private static func pathsMatchIgnoringParameterNames(_ lhs: String, _ rhs: String) -> Bool {
        let lhsSegments = lhs.split(separator: "/", omittingEmptySubsequences: false)
        let rhsSegments = rhs.split(separator: "/", omittingEmptySubsequences: false)
        guard lhsSegments.count == rhsSegments.count else {
            return false
        }

        return zip(lhsSegments, rhsSegments).allSatisfy { lhsSegment, rhsSegment in
            if isParameterSegment(lhsSegment), isParameterSegment(rhsSegment) {
                return true
            }
            return lhsSegment == rhsSegment
        }
    }

    private static func isParameterSegment(_ segment: Substring) -> Bool {
        segment.hasPrefix("{") && segment.hasSuffix("}")
    }
}
