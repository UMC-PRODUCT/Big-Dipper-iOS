import Foundation

public struct GitBlameRunner: Sendable {
    public init() {}

    public func blame(repoRoot: URL, file: String, line: Int) throws -> BlameInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "git",
            "blame",
            "-L",
            "\(line),\(line)",
            "--porcelain",
            "--",
            file,
        ]
        process.currentDirectoryURL = repoRoot

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            throw APICoverageError.blameFailed(file: file, reason: error)
        }

        let output = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return try parsePorcelain(output, file: file)
    }

    private func parsePorcelain(_ text: String, file: String) throws -> BlameInfo {
        var sha: String?
        var name: String?
        var email: String?
        var timestamp: TimeInterval?

        for line in text.split(separator: "\n") {
            if sha == nil,
               let first = line.split(separator: " ").first,
               first.count >= 7 {
                sha = String(first)
            }

            if line.hasPrefix("author ") {
                name = String(line.dropFirst("author ".count))
            } else if line.hasPrefix("author-mail ") {
                let mail = String(line.dropFirst("author-mail ".count))
                email = mail.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            } else if line.hasPrefix("author-time ") {
                timestamp = TimeInterval(line.dropFirst("author-time ".count))
            }
        }

        guard let sha, let name, let email, let timestamp else {
            throw APICoverageError.blameFailed(file: file, reason: "porcelain parse error")
        }

        return BlameInfo(
            email: email,
            name: name,
            commitSHA: sha,
            date: Date(timeIntervalSince1970: timestamp)
        )
    }
}
