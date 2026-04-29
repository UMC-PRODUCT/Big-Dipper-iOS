import Foundation

public struct Pipeline: Sendable {
    private let loader: OpenAPILoader
    private let finder: RouterFileFinder
    private let parser: RouterEnumParser
    private let blameRunner: GitBlameRunner

    public init(
        loader: OpenAPILoader = OpenAPILoader(),
        finder: RouterFileFinder = RouterFileFinder(),
        parser: RouterEnumParser = RouterEnumParser(),
        blameRunner: GitBlameRunner = GitBlameRunner()
    ) {
        self.loader = loader
        self.finder = finder
        self.parser = parser
        self.blameRunner = blameRunner
    }

    public func generate(_ config: ScanConfig, now: Date = Date()) async throws -> CoverageSnapshot {
        let openAPI = try await loader.load(config.openAPISource)
        let openAPIMap = openAPI.operationsByKey
        let overrides = try config.overridesURL.map { try OverridesLoader.load(from: $0) }
            ?? Overrides(entries: [])
        let authors = try config.authorsURL.map { try AuthorMapper.load(from: $0) }
            ?? AuthorMapper.empty
        let owners = try config.ownersURL.map { try OwnersLoader.load(from: $0) } ?? .empty

        let projectResults = try scanProjects(config.projects, openAPI: openAPIMap, overrides: overrides)
        let endpoints = buildEndpoints(
            operations: openAPI.operations,
            projectResults: projectResults,
            blameRoot: config.blameRoot,
            authors: authors,
            owners: owners
        )
        let unmatched = buildUnmatchedEntries(projectResults, blameRoot: config.blameRoot)
        let summary = buildSummary(projectResults, operationCount: openAPI.operations.count)

        return CoverageSnapshot(
            schemaVersion: CoverageSnapshot.currentSchemaVersion,
            generatedAt: now,
            openAPI: CoverageSnapshot.OpenAPISummary(
                title: openAPI.title,
                version: openAPI.version,
                totalPaths: openAPI.operations.count
            ),
            projects: config.projects.map {
                CoverageSnapshot.ProjectInfo(
                    key: $0.key,
                    displayName: $0.displayName,
                    rootPath: relativePath($0.rootPath.path, base: config.blameRoot)
                )
            },
            endpoints: endpoints.sorted {
                $0.key.path == $1.key.path
                    ? $0.key.method.rawValue < $1.key.method.rawValue
                    : $0.key.path < $1.key.path
            },
            unmatchedRouterCases: unmatched.sorted {
                "\($0.project).\($0.routerEnum).\($0.caseName)" <
                    "\($1.project).\($1.routerEnum).\($1.caseName)"
            },
            summary: summary
        )
    }

    private func scanProjects(
        _ projects: [ProjectInput],
        openAPI: [OpenAPIKey: OpenAPIOperation],
        overrides: Overrides
    ) throws -> [ProjectScanResult] {
        try projects.map { project in
            let files = try finder.find(in: project.rootPath, patterns: project.routerGlobs)
            let routerCases = try files.flatMap { try parser.parse(file: $0) }
            let matchResult = PathMatcher(openAPI: openAPI, overrides: overrides).match(routerCases)

            return ProjectScanResult(
                project: project,
                matched: matchResult.matched,
                unmatched: matchResult.unmatched
            )
        }
    }

    private func buildEndpoints(
        operations: [OpenAPIOperation],
        projectResults: [ProjectScanResult],
        blameRoot: URL,
        authors: AuthorMapper,
        owners: Owners
    ) -> [CoverageSnapshot.EndpointEntry] {
        operations.map { operation in
            var connections: [String: CoverageSnapshot.Connection?] = [:]

            for result in projectResults {
                if let matched = result.matched.first(where: { $0.openAPIKey == operation.key }) {
                    connections[result.project.key] = makeConnection(
                        matched: matched,
                        blameRoot: blameRoot,
                        authors: authors
                    )
                } else {
                    connections.updateValue(
                        Optional<CoverageSnapshot.Connection>.none,
                        forKey: result.project.key
                    )
                }
            }

            let owner = owners.email(for: operation.key, tag: operation.tag)
                .map { authors.author(forEmail: $0) }

            return CoverageSnapshot.EndpointEntry(
                key: operation.key,
                tag: operation.tag,
                operationId: operation.operationId,
                summary: operation.summary,
                description: operation.description,
                parameters: operation.parameters,
                requestBody: operation.requestBody,
                requestBodyExample: operation.requestBodyExample,
                responses: operation.responses,
                owner: owner,
                connections: connections
            )
        }
    }

    private func makeConnection(
        matched: MatchedRouterCase,
        blameRoot: URL,
        authors: AuthorMapper
    ) -> CoverageSnapshot.Connection {
        let relativeFilePath = relativePath(matched.routerCase.filePath, base: blameRoot)
        let blame: BlameInfo

        do {
            blame = try blameRunner.blame(
                repoRoot: blameRoot,
                file: relativeFilePath,
                line: matched.routerCase.line
            )
        } catch {
            blame = BlameInfo(
                email: "",
                name: "Unknown",
                commitSHA: "",
                date: Date(timeIntervalSince1970: 0)
            )
        }

        return CoverageSnapshot.Connection(
            routerEnum: matched.routerCase.routerEnum,
            caseName: matched.routerCase.caseName,
            filePath: relativeFilePath,
            line: matched.routerCase.line,
            author: authors.author(for: blame),
            lastCommitSHA: blame.commitSHA,
            lastCommitDate: blame.date
        )
    }

    private func buildUnmatchedEntries(
        _ projectResults: [ProjectScanResult],
        blameRoot: URL
    ) -> [CoverageSnapshot.UnmatchedEntry] {
        projectResults.flatMap { result in
            result.unmatched.map { unmatched in
                CoverageSnapshot.UnmatchedEntry(
                    project: result.project.key,
                    routerEnum: unmatched.routerCase.routerEnum,
                    caseName: unmatched.routerCase.caseName,
                    filePath: relativePath(unmatched.routerCase.filePath, base: blameRoot),
                    line: unmatched.routerCase.line,
                    reason: unmatched.reason
                )
            }
        }
    }

    private func buildSummary(
        _ projectResults: [ProjectScanResult],
        operationCount: Int
    ) -> [String: CoverageSnapshot.ProjectStats] {
        projectResults.reduce(into: [String: CoverageSnapshot.ProjectStats]()) { partial, result in
            partial[result.project.key] = CoverageSnapshot.ProjectStats(
                matched: result.matched.count,
                missing: operationCount - result.matched.count,
                unmatched: result.unmatched.count
            )
        }
    }

    private func relativePath(_ absolute: String, base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        guard absolute.hasPrefix(basePath + "/") else {
            return absolute
        }
        return String(absolute.dropFirst(basePath.count + 1))
    }
}
