import XCTest
@testable import APICoverageCore

final class AuthorMapperTests: XCTestCase {
    func testMappedAuthor() throws {
        let yaml = """
        authors:
          - email: tester@example.com
            displayName: 테스터
            github: tester
        """
        let mapper = try AuthorMapper.parse(yaml)
        let blame = BlameInfo(
            email: "tester@example.com",
            name: "Tester",
            commitSHA: "abc",
            date: Date()
        )

        let ref = mapper.author(for: blame)

        XCTAssertEqual(ref.displayName, "테스터")
        XCTAssertEqual(ref.githubUsername, "tester")
    }

    func testMappedAuthorIgnoresEmailCase() throws {
        let yaml = """
        authors:
          - email: tester@example.com
            displayName: 테스터
            github: tester
        """
        let mapper = try AuthorMapper.parse(yaml)
        let blame = BlameInfo(
            email: "TESTER@example.com",
            name: "Tester",
            commitSHA: "abc",
            date: Date()
        )

        let ref = mapper.author(for: blame)

        XCTAssertEqual(ref.displayName, "테스터")
    }

    func testUnmappedAuthorFallsBackToName() throws {
        let mapper = try AuthorMapper.parse("authors: []")
        let blame = BlameInfo(
            email: "unknown@x.com",
            name: "Unknown",
            commitSHA: "abc",
            date: Date()
        )

        let ref = mapper.author(for: blame)

        XCTAssertEqual(ref.displayName, "Unknown")
        XCTAssertNil(ref.githubUsername)
    }

    func testLoadFromFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "authors",
            withExtension: "yml",
            subdirectory: "Fixtures"
        ))

        let mapper = try AuthorMapper.load(from: url)
        let blame = BlameInfo(
            email: "tester@example.com",
            name: "Tester",
            commitSHA: "abc",
            date: Date()
        )
        let ref = mapper.author(for: blame)

        XCTAssertEqual(ref.displayName, "테스터")
        XCTAssertEqual(ref.githubUsername, "tester")
    }
}
