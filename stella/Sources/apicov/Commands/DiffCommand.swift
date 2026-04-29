import APICoverageCore
import ArgumentParser
import Foundation

struct DiffCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Diff two coverage snapshots"
    )

    @Argument
    var old: String

    @Argument
    var new: String

    func run() throws {
        let oldSnapshot = try SnapshotEncoder.decode(Data(contentsOf: URL(fileURLWithPath: old)))
        let newSnapshot = try SnapshotEncoder.decode(Data(contentsOf: URL(fileURLWithPath: new)))
        let diff = DiffFormatter.compute(old: oldSnapshot, new: newSnapshot)

        print(DiffFormatter.format(diff))
    }
}
