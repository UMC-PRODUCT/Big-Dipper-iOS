import APICoverageCore
import ArgumentParser
import Foundation

struct ReportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Render coverage snapshot as a self-contained HTML page"
    )

    @Argument(help: "Path to coverage.json")
    var snapshot: String

    @Option(name: .shortAndLong, help: "Output HTML path, defaults to stdout")
    var out: String?

    func run() throws {
        let url = URL(fileURLWithPath: snapshot).standardizedFileURL
        let data = try Data(contentsOf: url)
        let parsed = try SnapshotEncoder.decode(data)
        let html = HTMLReportFormatter.render(parsed)

        if let out {
            let outURL: URL = out.hasPrefix("/")
                ? URL(fileURLWithPath: out).standardizedFileURL
                : URL(
                    fileURLWithPath: out,
                    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                ).standardizedFileURL
            try Data(html.utf8).write(to: outURL)
            FileHandle.standardError.write(Data("wrote \(out) (\(html.utf8.count) bytes)\n".utf8))
        } else {
            FileHandle.standardOutput.write(Data(html.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
}
