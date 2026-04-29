import XCTest
@testable import StellaCore

final class PlaceholderTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertFalse(Stella.version.isEmpty)
    }
}
