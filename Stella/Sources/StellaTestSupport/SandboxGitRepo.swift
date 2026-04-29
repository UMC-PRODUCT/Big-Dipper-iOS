import Foundation

public final class SandboxGitRepo {
    public let url: URL

    public init() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StellaSandbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory

        try run(["git", "init", "-q"])
        try run(["git", "config", "user.email", "tester@example.com"])
        try run(["git", "config", "user.name", "Tester"])
        try run(["git", "config", "commit.gpgsign", "false"])
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    public func writeFile(_ relativePath: String, content: String) throws {
        let target = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: target, atomically: true, encoding: .utf8)
    }

    public func commit(message: String) throws {
        try run(["git", "add", "."])
        try run(["git", "commit", "-q", "-m", message])
    }

    @discardableResult
    public func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.currentDirectoryURL = url

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "SandboxGit",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
        return output
    }
}
