import XCTest
@testable import APICoverageCore

final class OpenAPIParserTests: XCTestCase {
    private func loadFixture() throws -> Data {
        let url = Bundle.module.url(forResource: "MiniOpenAPI", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    func testParsesTitleAndVersion() throws {
        let doc = try OpenAPIParser.parse(try loadFixture())
        XCTAssertEqual(doc.title, "Mini API")
        XCTAssertEqual(doc.version, "1.0.0")
    }

    func testExtractsAllOperations() throws {
        let doc = try OpenAPIParser.parse(try loadFixture())
        XCTAssertEqual(doc.operations.count, 4)
    }

    func testOperationKeyAndMetadata() throws {
        let doc = try OpenAPIParser.parse(try loadFixture())
        let getAll = doc.operations.first { $0.key.path == "/notices" && $0.key.method == .get }
        XCTAssertEqual(getAll?.operationId, "getAllNotices")
        XCTAssertEqual(getAll?.tag, "Notice")
        XCTAssertEqual(getAll?.summary, "공지 전체 조회")
    }
}
