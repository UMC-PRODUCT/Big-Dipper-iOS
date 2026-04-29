import APICoverageTestSupport
import XCTest
@testable import APICoverageCore

final class OpenAPILoaderTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testLoadsFromFile() async throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "MiniOpenAPI",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let loader = OpenAPILoader(session: URLSession(configuration: .ephemeral))
        let doc = try await loader.load(.file(url))

        XCTAssertEqual(doc.operations.count, 4)
    }

    func testLoadsFromData() async throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "MiniOpenAPI",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let loader = OpenAPILoader(session: URLSession(configuration: .ephemeral))
        let doc = try await loader.load(.data(try Data(contentsOf: url)))

        XCTAssertEqual(doc.title, "Mini API")
    }

    func testLoadsFromURLWithBasicAuth() async throws {
        let bodyURL = try XCTUnwrap(Bundle.module.url(
            forResource: "MiniOpenAPI",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let body = try Data(contentsOf: bodyURL)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Basic " + Data("user:pass".utf8).base64EncodedString()
            )
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let loader = OpenAPILoader(session: URLSession(configuration: .stubbed()))
        let doc = try await loader.load(.url(
            URL(string: "https://example.com/docs-json")!,
            auth: BasicAuth(user: "user", password: "pass")
        ))

        XCTAssertEqual(doc.title, "Mini API")
    }

    func testThrowsOnHTTPFailure() async {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        let loader = OpenAPILoader(session: URLSession(configuration: .stubbed()))

        do {
            _ = try await loader.load(.url(URL(string: "https://example.com/docs-json")!, auth: nil))
            XCTFail("expected error")
        } catch APICoverageError.openAPIHTTPStatus(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
