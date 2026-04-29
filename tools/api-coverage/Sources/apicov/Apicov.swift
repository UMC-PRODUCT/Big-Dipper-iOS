import ArgumentParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
@main
struct Apicov: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apicov",
        abstract: "UMC API coverage tool",
        version: "0.1.0",
        subcommands: [
            ScanCommand.self,
            DiffCommand.self,
            ReportCommand.self,
        ]
    )
}
