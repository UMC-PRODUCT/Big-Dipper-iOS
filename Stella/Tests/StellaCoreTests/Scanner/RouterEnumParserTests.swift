import XCTest
@testable import StellaCore

final class RouterEnumParserTests: XCTestCase {
    private var noticeRouterURL: URL {
        Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
            .appendingPathComponent("MiniRepo/AppProduct/Features/Notice/Data/Router/NoticeRouter.swift")
    }

    func testExtractsCaseNames() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)

        XCTAssertEqual(
            cases.map(\.caseName).sorted(),
            ["getAllNotices", "getDetailNotice", "postNotice"]
        )
    }

    func testExtractsEnumName() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)

        XCTAssertEqual(Set(cases.map(\.routerEnum)), ["NoticeRouter"])
    }

    func testCapturesLineNumbers() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)
        let getAll = try XCTUnwrap(cases.first { $0.caseName == "getAllNotices" })

        XCTAssertGreaterThan(getAll.line, 0)
    }

    func testCapturesDocCommentSummary() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)
        let getAll = try XCTUnwrap(cases.first { $0.caseName == "getAllNotices" })

        XCTAssertEqual(getAll.summary, "공지 전체 조회")
    }

    func testExtractsPathArmForLiteral() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)
        let getAll = try XCTUnwrap(cases.first { $0.caseName == "getAllNotices" })

        XCTAssertEqual(getAll.pathArm, "/notices")
    }

    func testExtractsPathArmForInterpolated() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)
        let detail = try XCTUnwrap(cases.first { $0.caseName == "getDetailNotice" })

        XCTAssertEqual(detail.pathArm, "/notices/\\(id)")
    }

    func testExtractsMethodArm() throws {
        let parser = RouterEnumParser()
        let cases = try parser.parse(file: noticeRouterURL)

        XCTAssertEqual(cases.first { $0.caseName == "getAllNotices" }?.methodArm, "get")
        XCTAssertEqual(cases.first { $0.caseName == "getDetailNotice" }?.methodArm, "get")
        XCTAssertEqual(cases.first { $0.caseName == "postNotice" }?.methodArm, "post")
    }
}
