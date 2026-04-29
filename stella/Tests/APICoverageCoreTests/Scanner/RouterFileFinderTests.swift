import XCTest
@testable import APICoverageCore

final class RouterFileFinderTests: XCTestCase {
    private var miniRepo: URL {
        Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
            .appendingPathComponent("MiniRepo")
    }

    func testFindsAppProductRouters() throws {
        let finder = RouterFileFinder()
        let files = try finder.find(
            in: miniRepo.appendingPathComponent("AppProduct"),
            patterns: ["**/Data/Router/*Router.swift"]
        )

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].lastPathComponent, "NoticeRouter.swift")
    }

    func testFindsUMCAppRouters() throws {
        let finder = RouterFileFinder()
        let files = try finder.find(
            in: miniRepo.appendingPathComponent("UMCApp"),
            patterns: ["**/Data/Sources/*Router.swift"]
        )

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].lastPathComponent, "AuthRouter.swift")
    }

    func testReturnsEmptyForUnknownPattern() throws {
        let finder = RouterFileFinder()
        let files = try finder.find(in: miniRepo, patterns: ["**/Nope*.swift"])

        XCTAssertEqual(files.count, 0)
    }
}
