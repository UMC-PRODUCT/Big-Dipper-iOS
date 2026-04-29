import XCTest
@testable import APICoverageCore

final class PlaceholderTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertFalse(APICoverage.version.isEmpty)
    }
}
