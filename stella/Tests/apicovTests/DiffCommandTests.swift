import APICoverageCore
import XCTest
@testable import apicov

final class DiffCommandTests: XCTestCase {
    func testNewlyConnected() {
        let oldSnapshot = makeSnapshot(matched: false)
        let newSnapshot = makeSnapshot(matched: true)

        let diff = DiffFormatter.compute(old: oldSnapshot, new: newSnapshot)

        XCTAssertEqual(diff.newlyConnected.count, 1)
        XCTAssertEqual(diff.newlyConnected[0].project, "appProduct")
        XCTAssertEqual(diff.newlyConnected[0].key, OpenAPIKey(method: .get, path: "/x"))
        XCTAssertEqual(diff.summaryDelta["appProduct"]?.matched, 1)
        XCTAssertEqual(diff.summaryDelta["appProduct"]?.missing, -1)
    }

    func testNewlyDisconnected() {
        let oldSnapshot = makeSnapshot(matched: true)
        let newSnapshot = makeSnapshot(matched: false)

        let diff = DiffFormatter.compute(old: oldSnapshot, new: newSnapshot)

        XCTAssertEqual(diff.newlyDisconnected.count, 1)
        XCTAssertEqual(diff.newlyDisconnected[0].project, "appProduct")
        XCTAssertEqual(diff.summaryDelta["appProduct"]?.matched, -1)
    }

    func testFormatIncludesSummaryAndConnectedEntries() {
        let diff = DiffFormatter.compute(old: makeSnapshot(matched: false), new: makeSnapshot(matched: true))

        let text = DiffFormatter.format(diff)

        XCTAssertTrue(text.contains("== Summary delta =="))
        XCTAssertTrue(text.contains("appProduct: matched +1, missing -1"))
        XCTAssertTrue(text.contains("+ [appProduct] GET /x"))
    }

    private func makeSnapshot(matched: Bool) -> CoverageSnapshot {
        let connection: CoverageSnapshot.Connection? = matched
            ? CoverageSnapshot.Connection(
                routerEnum: "XRouter",
                caseName: "x",
                filePath: "x.swift",
                line: 1,
                author: AuthorRef(
                    email: "",
                    name: "",
                    displayName: "",
                    githubUsername: nil
                ),
                lastCommitSHA: "",
                lastCommitDate: Date(timeIntervalSince1970: 0)
            )
            : nil

        return CoverageSnapshot(
            schemaVersion: CoverageSnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 0),
            openAPI: CoverageSnapshot.OpenAPISummary(title: "", version: "", totalPaths: 1),
            projects: [
                CoverageSnapshot.ProjectInfo(
                    key: "appProduct",
                    displayName: "AppProduct",
                    rootPath: "AppProduct"
                ),
            ],
            endpoints: [
                CoverageSnapshot.EndpointEntry(
                    key: OpenAPIKey(method: .get, path: "/x"),
                    tag: nil,
                    operationId: nil,
                    summary: nil,
                    connections: ["appProduct": connection]
                ),
            ],
            unmatchedRouterCases: [],
            summary: [
                "appProduct": CoverageSnapshot.ProjectStats(
                    matched: matched ? 1 : 0,
                    missing: matched ? 0 : 1,
                    unmatched: 0
                ),
            ]
        )
    }
}
