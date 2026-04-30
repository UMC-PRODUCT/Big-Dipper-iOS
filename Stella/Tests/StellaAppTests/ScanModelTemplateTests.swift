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
}
