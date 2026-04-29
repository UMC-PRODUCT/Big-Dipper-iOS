import XCTest
@testable import StellaCore

final class PathNormalizerTests: XCTestCase {
    func testLiteral() {
        XCTAssertEqual(PathNormalizer.normalize("/notices"), "/notices")
    }

    func testSingleInterpolation() {
        XCTAssertEqual(PathNormalizer.normalize("/notices/\\(id)"), "/notices/{id}")
    }

    func testMultipleInterpolation() {
        XCTAssertEqual(
            PathNormalizer.normalize("/notices/\\(id)/votes/\\(voteId)"),
            "/notices/{id}/votes/{voteId}"
        )
    }

    func testInterpolationWithMemberAccess() {
        XCTAssertEqual(PathNormalizer.normalize("/x/\\(request.id)"), "/x/{id}")
    }

    func testQueryStripped() {
        XCTAssertEqual(PathNormalizer.normalize("/notices?cursor=1"), "/notices")
    }
}
