import XCTest
@testable import StellaCore

final class PipelineTests: XCTestCase {
    private var fixtures: URL {
        Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
    }

    func testGeneratesSnapshotFromMiniRepo() async throws {
        let miniRepo = fixtures.appendingPathComponent("MiniRepo")
        let openAPI = fixtures.appendingPathComponent("MiniOpenAPI.json")
        let config = ScanConfig(
            openAPISource: .file(openAPI),
            projects: [
                .appProduct(rootPath: miniRepo.appendingPathComponent("AppProduct")),
                .umcApp(rootPath: miniRepo.appendingPathComponent("UMCApp")),
            ],
            overridesURL: fixtures.appendingPathComponent("overrides.yml"),
            authorsURL: fixtures.appendingPathComponent("authors.yml"),
            blameRoot: miniRepo
        )

        let snapshot = try await Pipeline().generate(
            config,
            now: Date(timeIntervalSince1970: 1_714_000_000)
        )

        XCTAssertEqual(snapshot.openAPI.totalPaths, 4)
        XCTAssertEqual(snapshot.projects.map(\.key), ["appProduct", "umcApp"])
        XCTAssertEqual(snapshot.summary["appProduct"], .init(matched: 3, missing: 1, unmatched: 0))
        XCTAssertEqual(snapshot.summary["umcApp"], .init(matched: 1, missing: 3, unmatched: 0))
        XCTAssertTrue(snapshot.unmatchedRouterCases.isEmpty)
    }

    func testEndpointConnectionsIncludeMissingProjectKeys() async throws {
        let miniRepo = fixtures.appendingPathComponent("MiniRepo")
        let openAPI = fixtures.appendingPathComponent("MiniOpenAPI.json")
        let config = ScanConfig(
            openAPISource: .file(openAPI),
            projects: [
                .appProduct(rootPath: miniRepo.appendingPathComponent("AppProduct")),
                .umcApp(rootPath: miniRepo.appendingPathComponent("UMCApp")),
            ],
            overridesURL: nil,
            authorsURL: nil,
            blameRoot: miniRepo
        )

        let snapshot = try await Pipeline().generate(config)
        let login = try XCTUnwrap(snapshot.endpoints.first {
            $0.key == OpenAPIKey(method: .post, path: "/auth/login")
        })

        XCTAssertTrue(login.connections.keys.contains("appProduct"))
        XCTAssertTrue(login.connections.keys.contains("umcApp"))
        XCTAssertEqual(login.connections["appProduct"]!, nil)
        XCTAssertEqual(login.connections["umcApp"]??.caseName, "login")
    }
}
