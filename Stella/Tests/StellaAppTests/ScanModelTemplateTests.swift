import XCTest
import StellaCore
@testable import StellaApp

@MainActor
final class ScanModelTemplateTests: XCTestCase {
    func testSpecTemplateOnlyPrefillsPageAndSize() {
        let model = ScanModel()
        let entry = CoverageSnapshot.EndpointEntry(
            key: OpenAPIKey(method: .get, path: "/api/v1/notices/{noticeId}"),
            tag: nil,
            operationId: "getNotice",
            summary: "공지 상세",
            parameters: [
                OpenAPIParameter(
                    name: "noticeId",
                    location: "path",
                    required: true,
                    description: "공지 ID",
                    schema: "integer"
                ),
                OpenAPIParameter(
                    name: "page",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "integer"
                ),
                OpenAPIParameter(
                    name: "size",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "integer"
                ),
                OpenAPIParameter(
                    name: "sort",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "string"
                ),
                OpenAPIParameter(
                    name: "cursor",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "string"
                ),
                OpenAPIParameter(
                    name: "limit",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "integer"
                )
            ],
            connections: [:]
        )

        model.prepareAPITestTemplate(for: entry)

        XCTAssertEqual(model.apiPathValues["noticeId"], "")
        XCTAssertEqual(model.apiQueryValues["page"], "0")
        XCTAssertEqual(model.apiQueryValues["size"], "20")
        XCTAssertEqual(model.apiQueryValues["sort"], "")
        XCTAssertEqual(model.apiQueryValues["cursor"], "")
        XCTAssertEqual(model.apiQueryValues["limit"], "")
    }

    func testSpecTemplateOverwriteReappliesBlankFallbacks() {
        let model = ScanModel()
        let entry = CoverageSnapshot.EndpointEntry(
            key: OpenAPIKey(method: .get, path: "/api/v1/posts/commented"),
            tag: nil,
            operationId: "getCommentedPosts",
            summary: "댓글 단 게시글",
            parameters: [
                OpenAPIParameter(
                    name: "page",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "integer"
                ),
                OpenAPIParameter(
                    name: "size",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "integer"
                ),
                OpenAPIParameter(
                    name: "sort",
                    location: "query",
                    required: false,
                    description: nil,
                    schema: "string"
                )
            ],
            connections: [:]
        )

        model.apiQueryValues = ["page": "3", "size": "50", "sort": "createdAt,DESC"]
        model.prepareAPITestTemplate(for: entry, overwrite: true)

        XCTAssertEqual(model.apiQueryValues["page"], "0")
        XCTAssertEqual(model.apiQueryValues["size"], "20")
        XCTAssertEqual(model.apiQueryValues["sort"], "")
    }

    func testOwnerManagerWritesAuthorsAndOwnersYAML() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StellaOwnerYAML-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let authorsURL = directory.appendingPathComponent("authors.yml")
        let ownersURL = directory.appendingPathComponent("owners.yml")
        let model = ScanModel()
        model.authorsPath = authorsURL.path
        model.ownersPath = ownersURL.path

        model.upsertOwner(EditableOwner(
            email: "lee@example.com",
            displayName: "이담당",
            githubUsername: "lee"
        ))

        let authorsYAML = try String(contentsOf: authorsURL, encoding: .utf8)
        XCTAssertTrue(authorsYAML.contains("email: lee@example.com"))
        XCTAssertTrue(authorsYAML.contains("displayName: 이담당"))
        XCTAssertTrue(authorsYAML.contains("github: lee"))

        let entry = CoverageSnapshot.EndpointEntry(
            key: OpenAPIKey(method: .post, path: "/api/v1/notices"),
            tag: nil,
            operationId: "createNotice",
            summary: "공지 생성",
            connections: [:]
        )
        model.assignOwner(email: "lee@example.com", to: entry)

        let ownersYAML = try String(contentsOf: ownersURL, encoding: .utf8)
        XCTAssertTrue(ownersYAML.contains("method: POST"))
        XCTAssertTrue(ownersYAML.contains("path: /api/v1/notices"))
        XCTAssertTrue(ownersYAML.contains("owner: lee@example.com"))
    }

    func testOwnerManagerCreatesMissingYAMLDirectories() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StellaOwnerYAMLMissingDirectory-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let authorsURL = directory.appendingPathComponent("tools/api-coverage/authors.yml")
        let model = ScanModel()
        model.authorsPath = authorsURL.path

        model.upsertOwner(EditableOwner(
            email: "one@example.com",
            displayName: "원",
            githubUsername: "one"
        ))

        XCTAssertTrue(FileManager.default.fileExists(atPath: authorsURL.path))
        let authorsYAML = try String(contentsOf: authorsURL, encoding: .utf8)
        XCTAssertTrue(authorsYAML.contains("email: one@example.com"))
    }

    func testOwnerYAMLFilesLoadIntoEditableState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StellaOwnerYAMLLoad-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let authorsURL = directory.appendingPathComponent("authors.yml")
        let ownersURL = directory.appendingPathComponent("owners.yml")
        try """
        authors:
          - email: kim@example.com
            displayName: 김담당
            github: kim
        """.write(to: authorsURL, atomically: true, encoding: .utf8)
        try """
        owners:
          endpoints:
            - method: GET
              path: /api/v1/members
              owner: kim@example.com
        """.write(to: ownersURL, atomically: true, encoding: .utf8)

        let model = ScanModel()
        model.authorsPath = authorsURL.path
        model.ownersPath = ownersURL.path
        model.loadOwnerYAMLFiles()

        XCTAssertEqual(model.manualOwners.first?.email, "kim@example.com")
        XCTAssertEqual(model.manualOwners.first?.displayName, "김담당")
        XCTAssertEqual(model.manualOwners.first?.githubUsername, "kim")
        XCTAssertEqual(model.ownerAssignments["GET /api/v1/members"], "kim@example.com")
    }
}
