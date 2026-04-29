import APICoverageTestSupport
import XCTest
@testable import APICoverageCore

final class GitBlameRunnerTests: XCTestCase {
    func testBlamesSingleLine() throws {
        let repo = try SandboxGitRepo()
        try repo.writeFile("src/file.swift", content: "case getAllNotices\n")
        try repo.commit(message: "add")

        let runner = GitBlameRunner()
        let info = try runner.blame(repoRoot: repo.url, file: "src/file.swift", line: 1)

        XCTAssertEqual(info.email, "tester@example.com")
        XCTAssertEqual(info.name, "Tester")
        XCTAssertFalse(info.commitSHA.isEmpty)
    }

    func testThrowsForNonGit() throws {
        let runner = GitBlameRunner()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        XCTAssertThrowsError(try runner.blame(
            repoRoot: temporaryDirectory,
            file: "x.swift",
            line: 1
        ))
    }
}
