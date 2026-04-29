import XCTest
@testable import APICoverageCore

final class PathMatcherTests: XCTestCase {
    private let openAPI: [OpenAPIKey: OpenAPIOperation] = [
        OpenAPIKey(method: .get, path: "/notices"): OpenAPIOperation(
            key: OpenAPIKey(method: .get, path: "/notices"),
            tag: "Notice",
            operationId: "getAllNotices",
            summary: nil
        ),
        OpenAPIKey(method: .get, path: "/notices/{id}"): OpenAPIOperation(
            key: OpenAPIKey(method: .get, path: "/notices/{id}"),
            tag: "Notice",
            operationId: "getDetailNotice",
            summary: nil
        ),
    ]

    func testStrictMatch() {
        let routerCase = RouterCase(
            routerEnum: "NoticeRouter",
            caseName: "getAllNotices",
            filePath: "/x.swift",
            line: 1,
            pathArm: "/notices",
            methodArm: "get",
            summary: nil
        )
        let matcher = PathMatcher(openAPI: openAPI, overrides: Overrides(entries: []))

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.matched.count, 1)
        XCTAssertEqual(result.matched[0].openAPIKey.path, "/notices")
        XCTAssertTrue(result.unmatched.isEmpty)
    }

    func testInterpolationNormalized() {
        let routerCase = RouterCase(
            routerEnum: "NoticeRouter",
            caseName: "getDetailNotice",
            filePath: "/x.swift",
            line: 1,
            pathArm: "/notices/\\(id)",
            methodArm: "get",
            summary: nil
        )
        let matcher = PathMatcher(openAPI: openAPI, overrides: Overrides(entries: []))

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.matched.first?.openAPIKey.path, "/notices/{id}")
    }

    func testUnmatchedReason() {
        let routerCase = RouterCase(
            routerEnum: "X",
            caseName: "y",
            filePath: "/x.swift",
            line: 1,
            pathArm: nil,
            methodArm: nil,
            summary: nil
        )
        let matcher = PathMatcher(openAPI: openAPI, overrides: Overrides(entries: []))

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.unmatched.count, 1)
        XCTAssertEqual(result.unmatched[0].reason, "missing path or method arm")
    }

    func testParameterNameMismatchStillMatchesTemplate() {
        let routerCase = RouterCase(
            routerEnum: "NoticeRouter",
            caseName: "getDetailNotice",
            filePath: "/x.swift",
            line: 1,
            pathArm: "/notices/\\(noticeId)",
            methodArm: "get",
            summary: nil
        )
        let matcher = PathMatcher(openAPI: openAPI, overrides: Overrides(entries: []))

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.matched.first?.openAPIKey.path, "/notices/{id}")
        XCTAssertTrue(result.unmatched.isEmpty)
    }

    func testOverrideRemap() {
        let routerCase = RouterCase(
            routerEnum: "NoticeRouter",
            caseName: "weird",
            filePath: "/x.swift",
            line: 1,
            pathArm: nil,
            methodArm: nil,
            summary: nil
        )
        let overrides = Overrides(entries: [
            Overrides.Entry(
                routerEnum: "NoticeRouter",
                caseName: "weird",
                target: .remap(OpenAPIKey(method: .get, path: "/notices"))
            ),
        ])
        let matcher = PathMatcher(openAPI: openAPI, overrides: overrides)

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.matched.first?.openAPIKey.path, "/notices")
    }

    func testOverrideIgnore() {
        let routerCase = RouterCase(
            routerEnum: "NoticeRouter",
            caseName: "third",
            filePath: "/x.swift",
            line: 1,
            pathArm: "/something",
            methodArm: "get",
            summary: nil
        )
        let overrides = Overrides(entries: [
            Overrides.Entry(
                routerEnum: "NoticeRouter",
                caseName: "third",
                target: .ignore(reason: "third-party")
            ),
        ])
        let matcher = PathMatcher(openAPI: openAPI, overrides: overrides)

        let result = matcher.match([routerCase])

        XCTAssertEqual(result.unmatched.count, 1)
        XCTAssertEqual(result.unmatched[0].reason, "ignored: third-party")
    }
}
