import XCTest
@testable import StellaCore

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

    func testParsesResponseContentAndExampleFromSchema() throws {
        let json = """
        {
          "openapi": "3.1.0",
          "info": { "title": "Response API", "version": "1.0.0" },
          "paths": {
            "/notices/{noticeId}/read-status": {
              "get": {
                "operationId": "readStatus",
                "responses": {
                  "200": {
                    "description": "조회 성공",
                    "content": {
                      "application/json": {
                        "schema": { "$ref": "#/components/schemas/ReadStatusResponse" }
                      }
                    }
                  },
                  "401": {
                    "description": "인증 정보가 전달되지 않았습니다."
                  }
                }
              }
            }
          },
          "components": {
            "schemas": {
              "ReadStatusResponse": {
                "type": "object",
                "properties": {
                  "success": { "type": "boolean" },
                  "result": {
                    "type": "array",
                    "items": { "$ref": "#/components/schemas/ReadStatusItem" }
                  }
                }
              },
              "ReadStatusItem": {
                "type": "object",
                "properties": {
                  "memberId": { "type": "integer", "format": "int64" },
                  "nickname": { "type": "string" }
                }
              }
            }
          }
        }
        """

        let doc = try OpenAPIParser.parse(Data(json.utf8))
        let operation = try XCTUnwrap(doc.operations.first)
        let success = try XCTUnwrap(operation.responses.first { $0.statusCode == "200" })

        XCTAssertEqual(success.description, "조회 성공")
        XCTAssertEqual(success.content, "content: application/json")
        let example = try XCTUnwrap(success.example)
        let exampleData = try XCTUnwrap(example.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: exampleData) as? [String: Any])
        XCTAssertEqual(object["success"] as? Bool, false)
        let result = try XCTUnwrap(object["result"] as? [[String: Any]])
        XCTAssertEqual(result.first?["memberId"] as? Int, 0)
        XCTAssertEqual(result.first?["nickname"] as? String, "string")

        let unauthorized = try XCTUnwrap(operation.responses.first { $0.statusCode == "401" })
        XCTAssertEqual(unauthorized.description, "인증 정보가 전달되지 않았습니다.")
        XCTAssertNil(unauthorized.content)
        XCTAssertNil(unauthorized.example)
    }
}
