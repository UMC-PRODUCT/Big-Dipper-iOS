import StellaCore
import StellaTestSupport
import XCTest
@testable import apicov

final class ScanCommandTests: XCTestCase {
    func testScanProducesValidSnapshot() async throws {
        let sandbox = try SandboxGitRepo()
        let fixturesURL = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
        try copyDirectory(
            from: fixturesURL.appendingPathComponent("MiniRepo"),
            into: sandbox.url.appendingPathComponent("MiniRepo")
        )
        try sandbox.commit(message: "import")

        let outURL = sandbox.url.appendingPathComponent("out.json")
        let command = try ScanCommand.parse([
            "--openapi-file",
            fixturesURL.appendingPathComponent("MiniOpenAPI.json").path,
            "--app-product",
            "MiniRepo/AppProduct",
            "--umc-app",
            "MiniRepo/UMCApp",
            "--blame-root",
            sandbox.url.path,
            "--authors",
            fixturesURL.appendingPathComponent("authors.yml").path,
            "--owners",
            fixturesURL.appendingPathComponent("owners.yml").path,
            "--out",
            outURL.path,
        ])

        try await command.run()

        let snapshot = try SnapshotEncoder.decode(Data(contentsOf: outURL))
        XCTAssertEqual(snapshot.endpoints.count, 4)
        XCTAssertEqual(snapshot.summary["appProduct"]?.matched, 3)
        XCTAssertEqual(snapshot.summary["umcApp"]?.matched, 1)

        let noticeList = try XCTUnwrap(snapshot.endpoints.first {
            $0.key == OpenAPIKey(method: .get, path: "/notices")
        })
        XCTAssertEqual(noticeList.owner?.email, "tester@example.com")
        XCTAssertEqual(noticeList.owner?.displayName, "테스터")
    }

    private func copyDirectory(from source: URL, into destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let items = try FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil
        )

        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                try copyDirectory(from: item, into: target)
            } else {
                try FileManager.default.copyItem(at: item, to: target)
            }
        }
    }
}
