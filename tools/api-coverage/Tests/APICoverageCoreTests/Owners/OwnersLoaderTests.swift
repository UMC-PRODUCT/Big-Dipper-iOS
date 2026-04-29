import XCTest
@testable import APICoverageCore

final class OwnersLoaderTests: XCTestCase {
    func testEmptyOwners() throws {
        let yaml = "owners: {}"

        let result = try OwnersLoader.parse(yaml)

        XCTAssertTrue(result.tagOwners.isEmpty)
        XCTAssertTrue(result.endpointOwners.isEmpty)
    }

    func testTagOwners() throws {
        let yaml = """
        owners:
          tags:
            Notice: a@x.com
            Auth: b@x.com
        """

        let result = try OwnersLoader.parse(yaml)

        XCTAssertEqual(result.tagOwners["Notice"], "a@x.com")
        XCTAssertEqual(result.tagOwners["Auth"], "b@x.com")
    }

    func testEndpointOwners() throws {
        let yaml = """
        owners:
          endpoints:
            - method: GET
              path: /notices/{id}
              owner: a@x.com
        """

        let result = try OwnersLoader.parse(yaml)
        let key = OpenAPIKey(method: .get, path: "/notices/{id}")

        XCTAssertEqual(result.endpointOwners[key], "a@x.com")
    }

    func testEndpointOwnerOverridesTagOwner() throws {
        let yaml = """
        owners:
          tags:
            Notice: tag@x.com
          endpoints:
            - method: GET
              path: /notices/{id}
              owner: direct@x.com
        """

        let result = try OwnersLoader.parse(yaml)
        let key = OpenAPIKey(method: .get, path: "/notices/{id}")

        XCTAssertEqual(result.email(for: key, tag: "Notice"), "direct@x.com")
    }

    func testTagOwnerFallsBackWhenEndpointMissing() throws {
        let yaml = """
        owners:
          tags:
            Notice: tag@x.com
        """

        let result = try OwnersLoader.parse(yaml)
        let key = OpenAPIKey(method: .post, path: "/notices")

        XCTAssertEqual(result.email(for: key, tag: "Notice"), "tag@x.com")
    }

    func testNoOwnerWhenNothingMatches() throws {
        let result = Owners.empty
        let key = OpenAPIKey(method: .get, path: "/x")

        XCTAssertNil(result.email(for: key, tag: "Y"))
        XCTAssertNil(result.email(for: key, tag: nil))
    }

    func testThrowsOnMalformedEndpoint() {
        let yaml = """
        owners:
          endpoints:
            - method: GET
              path: /notices
              # owner missing
        """

        XCTAssertThrowsError(try OwnersLoader.parse(yaml))
    }

    func testSerializeRoundTrip() throws {
        let original = Owners(
            tagOwners: ["Auth": "a@x.com", "Notice": "b@x.com"],
            endpointOwners: [
                OpenAPIKey(method: .post, path: "/auth/login"): "c@x.com",
                OpenAPIKey(method: .get, path: "/notices/{id}"): "d@x.com",
            ]
        )

        let yaml = OwnersLoader.serialize(original)
        let parsed = try OwnersLoader.parse(yaml)

        XCTAssertEqual(parsed.tagOwners, original.tagOwners)
        XCTAssertEqual(parsed.endpointOwners, original.endpointOwners)
    }

    func testSerializeEmitsEmptyMappingForNoOwners() {
        XCTAssertEqual(OwnersLoader.serialize(.empty), "owners: {}\n")
    }

    func testSerializeQuotesPathsWithBraces() {
        let owners = Owners(
            tagOwners: [:],
            endpointOwners: [OpenAPIKey(method: .get, path: "/notices/{id}"): "a@x.com"]
        )

        let yaml = OwnersLoader.serialize(owners)

        XCTAssertTrue(yaml.contains("path: \"/notices/{id}\""))
    }

    func testLoadFromFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "owners",
            withExtension: "yml",
            subdirectory: "Fixtures"
        ))

        let result = try OwnersLoader.load(from: url)

        XCTAssertEqual(result.tagOwners["Notice"], "tester@example.com")
        XCTAssertEqual(
            result.endpointOwners[OpenAPIKey(method: .post, path: "/auth/login")],
            "tester@example.com"
        )
    }
}
