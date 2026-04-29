import XCTest
@testable import StellaCore

final class OverridesLoaderTests: XCTestCase {
    func testEmptyOverrides() throws {
        let yaml = """
        overrides: []
        """

        let result = try OverridesLoader.parse(yaml)

        XCTAssertTrue(result.entries.isEmpty)
    }

    func testRemap() throws {
        let yaml = """
        overrides:
          - routerCase: NoticeRouter.searchNotice
            openAPI:
              method: GET
              path: /notices/search
        """

        let result = try OverridesLoader.parse(yaml)

        XCTAssertEqual(result.entries.count, 1)
        let entry = result.entries[0]
        XCTAssertEqual(entry.routerEnum, "NoticeRouter")
        XCTAssertEqual(entry.caseName, "searchNotice")
        XCTAssertEqual(entry.target, .remap(OpenAPIKey(method: .get, path: "/notices/search")))
    }

    func testIgnore() throws {
        let yaml = """
        overrides:
          - routerCase: TMapGeocodingRouter.geocode
            ignore: true
            reason: "Third-party"
        """

        let result = try OverridesLoader.parse(yaml)

        XCTAssertEqual(result.entries[0].target, .ignore(reason: "Third-party"))
    }

    func testLoadFromFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "overrides",
            withExtension: "yml",
            subdirectory: "Fixtures"
        ))

        let result = try OverridesLoader.load(from: url)

        XCTAssertTrue(result.entries.isEmpty)
    }
}
