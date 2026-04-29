import XCTest
@testable import APICoverageCore

final class CoverageSnapshotTests: XCTestCase {
    func testRoundtrip() throws {
        let snapshot = makeSampleSnapshot()

        let data = try SnapshotEncoder.encode(snapshot)
        let decoded = try SnapshotEncoder.decode(data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testStableKeyOrdering() throws {
        let snapshot = makeSampleSnapshot()

        let first = try SnapshotEncoder.encode(snapshot)
        let second = try SnapshotEncoder.encode(snapshot)

        XCTAssertEqual(first, second)
    }

    func testSchemaVersion() {
        XCTAssertEqual(CoverageSnapshot.currentSchemaVersion, 1)
    }

    private func makeSampleSnapshot() -> CoverageSnapshot {
        CoverageSnapshot(
            schemaVersion: CoverageSnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_714_000_000),
            openAPI: CoverageSnapshot.OpenAPISummary(
                title: "Mini",
                version: "1.0.0",
                totalPaths: 4
            ),
            projects: [
                CoverageSnapshot.ProjectInfo(
                    key: "appProduct",
                    displayName: "AppProduct",
                    rootPath: "AppProduct"
                ),
            ],
            endpoints: [
                CoverageSnapshot.EndpointEntry(
                    key: OpenAPIKey(method: .get, path: "/notices"),
                    tag: "Notice",
                    operationId: "getAllNotices",
                    summary: "공지",
                    connections: [
                        "appProduct": CoverageSnapshot.Connection(
                            routerEnum: "NoticeRouter",
                            caseName: "getAllNotices",
                            filePath: "x.swift",
                            line: 4,
                            author: AuthorRef(
                                email: "t@x.com",
                                name: "T",
                                displayName: "T",
                                githubUsername: nil
                            ),
                            lastCommitSHA: "abc",
                            lastCommitDate: Date(timeIntervalSince1970: 1_713_000_000)
                        ),
                    ]
                ),
            ],
            unmatchedRouterCases: [],
            summary: [
                "appProduct": CoverageSnapshot.ProjectStats(
                    matched: 1,
                    missing: 0,
                    unmatched: 0
                ),
            ]
        )
    }
}
