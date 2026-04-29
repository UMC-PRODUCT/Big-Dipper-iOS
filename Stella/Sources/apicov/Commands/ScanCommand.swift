import StellaCore
import ArgumentParser
import Foundation

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan iOS Moya routers and emit coverage.json"
    )

    @Option(name: .customLong("openapi-url"))
    var openAPIURL: String?

    @Option(name: .customLong("openapi-file"))
    var openAPIFile: String?

    @Option(
        name: .customLong("auth-env"),
        help: "USER_VAR:PASS_VAR - read Basic Auth from env vars"
    )
    var authEnv: String?

    @Option(name: .customLong("app-product"), help: "AppProduct repo subdirectory")
    var appProduct: String?

    @Option(name: .customLong("umc-app"), help: "UMCApp repo subdirectory")
    var umcApp: String?

    @Option(name: .customLong("blame-root"), help: "Git repo root, defaults to current directory")
    var blameRoot: String?

    @Option
    var overrides: String?

    @Option
    var authors: String?

    @Option(help: "Endpoint owner mapping YAML")
    var owners: String?

    @Option(name: .shortAndLong, help: "Output path, defaults to stdout")
    var out: String?

    func run() async throws {
        let rootURL = absoluteURL(blameRoot ?? FileManager.default.currentDirectoryPath)
        let config = ScanConfig(
            openAPISource: try openAPISource(),
            projects: try projectInputs(blameRoot: rootURL),
            overridesURL: overrides.map(absoluteURL(_:)),
            authorsURL: authors.map(absoluteURL(_:)),
            ownersURL: owners.map(absoluteURL(_:)),
            blameRoot: rootURL
        )

        let snapshot = try await Pipeline().generate(config)
        let data = try SnapshotEncoder.encode(snapshot)

        if let out {
            try data.write(to: absoluteURL(out))
            FileHandle.standardError.write(Data("wrote \(out) (\(data.count) bytes)\n".utf8))
        } else {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }

    private func projectInputs(blameRoot: URL) throws -> [ProjectInput] {
        var projects: [ProjectInput] = []

        if let appProduct {
            projects.append(.appProduct(rootPath: projectURL(appProduct, blameRoot: blameRoot)))
        }
        if let umcApp {
            projects.append(.umcApp(rootPath: projectURL(umcApp, blameRoot: blameRoot)))
        }
        guard !projects.isEmpty else {
            throw ValidationError("at least one of --app-product / --umc-app required")
        }
        return projects
    }

    private func openAPISource() throws -> OpenAPISource {
        if let openAPIFile {
            return .file(absoluteURL(openAPIFile))
        }

        guard let openAPIURL, let url = URL(string: openAPIURL) else {
            throw ValidationError("--openapi-url or --openapi-file required")
        }
        guard let authEnv else {
            return .url(url, auth: nil)
        }

        let parts = authEnv.split(separator: ":").map(String.init)
        guard parts.count == 2,
              let user = ProcessInfo.processInfo.environment[parts[0]],
              let password = ProcessInfo.processInfo.environment[parts[1]]
        else {
            throw ValidationError("auth-env vars not set: \(authEnv)")
        }

        return .url(url, auth: BasicAuth(user: user, password: password))
    }

    private func projectURL(_ path: String, blameRoot: URL) -> URL {
        if path.hasPrefix("/") || path.hasPrefix(".") {
            return absoluteURL(path)
        }
        return blameRoot.appendingPathComponent(path).standardizedFileURL
    }

    private func absoluteURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return URL(fileURLWithPath: path, relativeTo: currentDirectory).standardizedFileURL
    }
}
