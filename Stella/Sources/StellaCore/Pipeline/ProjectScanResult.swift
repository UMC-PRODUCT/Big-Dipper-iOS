import Foundation

struct ProjectScanResult: Sendable {
    let project: ProjectInput
    let matched: [MatchedRouterCase]
    let unmatched: [UnmatchedRouterCase]
}
