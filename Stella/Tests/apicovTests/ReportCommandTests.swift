import StellaCore
import XCTest
@testable import apicov

final class ReportCommandTests: XCTestCase {
    func testRendersSnapshotToHTML() throws {
        let snapshot = makeSnapshot()
        let html = HTMLReportFormatter.render(snapshot)

        XCTAssertTrue(html.contains("<title>Stella — API Coverage</title>"))
        XCTAssertTrue(html.contains("Mini API"))
        XCTAssertTrue(html.contains("/notices"))
        XCTAssertTrue(html.contains("Notice"))
    }

    func testIncludesOwnerColumnAndRollup() throws {
        let snapshot = makeSnapshot()
        let html = HTMLReportFormatter.render(snapshot)

        XCTAssertTrue(html.contains("담당자별 엔드포인트"))
        XCTAssertTrue(html.contains("테스터"))
        XCTAssertTrue(html.contains("class=\"owner\""))
    }

    func testEscapesHTMLSpecialChars() throws {
        let snapshot = CoverageSnapshot(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 0),
            openAPI: .init(title: "<script>alert(1)</script>", version: "1", totalPaths: 0),
            projects: [],
            endpoints: [],
            unmatchedRouterCases: [],
            summary: [:]
        )

        let html = HTMLReportFormatter.render(snapshot)

        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    }

    func testWritesToOutputFile() throws {
        let snapshot = makeSnapshot()
        let snapshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apicov-report-\(UUID()).json")
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apicov-report-\(UUID()).html")
        defer {
            try? FileManager.default.removeItem(at: snapshotURL)
            try? FileManager.default.removeItem(at: outURL)
        }
        try SnapshotEncoder.encode(snapshot).write(to: snapshotURL)

        let command = try ReportCommand.parse([snapshotURL.path, "--out", outURL.path])
        try command.run()

        let html = try String(contentsOf: outURL, encoding: .utf8)
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("Stella"))
    }

    private func makeSnapshot() -> CoverageSnapshot {
        let owner = AuthorRef(
            email: "tester@example.com",
            name: "테스터",
            displayName: "테스터",
            githubUsername: "tester"
        )
        let connection = CoverageSnapshot.Connection(
            routerEnum: "NoticeRouter",
            caseName: "list",
            filePath: "Features/Notice/Router/NoticeRouter.swift",
            line: 12,
            author: owner,
            lastCommitSHA: "abc1234",
            lastCommitDate: Date(timeIntervalSince1970: 0)
        )
        return CoverageSnapshot(
            schemaVersion: 1,
            generatedAt: Date(timeIntervalSince1970: 1_714_000_000),
            openAPI: .init(title: "Mini API", version: "1.0.0", totalPaths: 1),
            projects: [
                .init(key: "appProduct", displayName: "AppProduct", rootPath: "AppProduct"),
            ],
            endpoints: [
                .init(
                    key: OpenAPIKey(method: .get, path: "/notices"),
                    tag: "Notice",
                    operationId: "listNotices",
                    summary: "공지 목록",
                    owner: owner,
                    connections: ["appProduct": connection]
                ),
            ],
            unmatchedRouterCases: [],
            summary: ["appProduct": .init(matched: 1, missing: 0, unmatched: 0)]
        )
    }
}
