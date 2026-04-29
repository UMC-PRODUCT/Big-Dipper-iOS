import Foundation
import Observation
import AppKit
import StellaCore

struct EditableOwner: Identifiable, Codable, Hashable {
    var id: String { email }
    var email: String
    var displayName: String
    var githubUsername: String

    var authorRef: AuthorRef {
        AuthorRef(
            email: email,
            name: displayName.isEmpty ? email : displayName,
            displayName: displayName.isEmpty ? email : displayName,
            githubUsername: githubUsername.isEmpty ? nil : githubUsername
        )
    }
}

enum SourceMode: String, CaseIterable, Identifiable {
    case url = "URL"
    case file = "파일"
    var id: String { rawValue }
}

struct APIParameterField: Identifiable, Hashable {
    let name: String
    let location: String
    let type: String?
    let required: Bool
    let description: String?

    var id: String { "\(location):\(name)" }
}

enum ScanState: Equatable {
    case idle
    case running
    case loaded
    case failed(String)
}

@Observable
@MainActor
final class ScanModel {
    // Form
    var sourceMode: SourceMode = .url
    var openAPIURL: String = "https://dev.api.umc.it.kr/docs-json"
    var openAPIFile: String = ""
    var basicUser: String = ""
    var basicPass: String = ""
    var appProductPath: String = ""
    var umcAppPath: String = ""
    var blameRoot: String = ""
    var authorsPath: String = ""
    var overridesPath: String = ""
    var ownersPath: String = ""
    var apiBaseURL: String = "https://dev.api.umc.it.kr"
    var bearerToken: String = ""
    var manualOwners: [EditableOwner] = []
    var ownerAssignments: [String: String] = [:]

    // Result
    var state: ScanState = .idle
    var snapshot: CoverageSnapshot?
    var statusMessage: String = ""
    var apiPathValues: [String: String] = [:]
    var apiQueryValues: [String: String] = [:]
    var apiRequestBody: String = ""
    var apiResponseText: String = ""
    var isAPITestRunning = false

    // Filters
    var query: String = ""
    var methodFilter: HTTPMethod?
    var connectionFilter: ConnectionFilter = .all
    var selectedTag: String?
    var selectedOwner: String?

    enum ConnectionFilter: String, CaseIterable, Identifiable {
        case all = "전체"
        case onlyMatched = "매치됨"
        case onlyMissing = "누락"
        case mixed = "부분 매치"
        var id: String { rawValue }
    }

    var isRunning: Bool { state == .running }

    init() {
        let repoRoot = Self.inferRepoRoot()
        let pkgRoot = repoRoot.appendingPathComponent("Stella")
        self.appProductPath = repoRoot.appendingPathComponent("AppProduct").path
        self.umcAppPath = repoRoot.appendingPathComponent("UMCApp").path
        self.blameRoot = repoRoot.path
        self.authorsPath = pkgRoot.appendingPathComponent("authors.yml").path
        self.overridesPath = pkgRoot.appendingPathComponent("overrides.yml").path
        self.ownersPath = pkgRoot.appendingPathComponent("owners.yml").path
        loadDefaults()
    }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private func loadDefaults() {
        if let v = defaults.string(forKey: "openAPIURL") { openAPIURL = v }
        if let v = defaults.string(forKey: "openAPIFile") { openAPIFile = v }
        if let v = defaults.string(forKey: "appProductPath"), !v.isEmpty { appProductPath = v }
        if let v = defaults.string(forKey: "umcAppPath"), !v.isEmpty { umcAppPath = v }
        if let v = defaults.string(forKey: "blameRoot"), !v.isEmpty { blameRoot = v }
        if let v = defaults.string(forKey: "authorsPath"), !v.isEmpty { authorsPath = v }
        if let v = defaults.string(forKey: "overridesPath"), !v.isEmpty { overridesPath = v }
        if let v = defaults.string(forKey: "ownersPath"), !v.isEmpty { ownersPath = v }
        if let v = defaults.string(forKey: "sourceMode"), let mode = SourceMode(rawValue: v) {
            sourceMode = mode
        }
        if let v = defaults.string(forKey: "apiBaseURL"), !v.isEmpty { apiBaseURL = v }
        basicUser = defaults.string(forKey: "basicUser") ?? ""
        basicPass = defaults.string(forKey: "basicPass") ?? ""
        bearerToken = KeychainStore.read("bearerToken")
        manualOwners = loadJSON([EditableOwner].self, key: "manualOwners") ?? []
        ownerAssignments = loadJSON([String: String].self, key: "ownerAssignments") ?? [:]
    }

    func persistDefaults() {
        defaults.set(openAPIURL, forKey: "openAPIURL")
        defaults.set(openAPIFile, forKey: "openAPIFile")
        defaults.set(appProductPath, forKey: "appProductPath")
        defaults.set(umcAppPath, forKey: "umcAppPath")
        defaults.set(blameRoot, forKey: "blameRoot")
        defaults.set(authorsPath, forKey: "authorsPath")
        defaults.set(overridesPath, forKey: "overridesPath")
        defaults.set(ownersPath, forKey: "ownersPath")
        defaults.set(sourceMode.rawValue, forKey: "sourceMode")
        defaults.set(apiBaseURL, forKey: "apiBaseURL")
        defaults.set(basicUser, forKey: "basicUser")
        defaults.set(basicPass, forKey: "basicPass")
        KeychainStore.write(bearerToken, account: "bearerToken")
        saveJSON(manualOwners, key: "manualOwners")
        saveJSON(ownerAssignments, key: "ownerAssignments")
    }

    // MARK: - Scan

    func runScan() async {
        persistDefaults()
        state = .running
        statusMessage = "스캔 중…"
        do {
            let config = try buildConfig()
            let pipeline = Pipeline()
            let result = try await pipeline.generate(config)
            snapshot = applyingManualOwners(to: result)
            state = .loaded
            statusMessage = "\(formattedTimestamp(result.generatedAt))에 엔드포인트 \(result.endpoints.count)개 스캔됨"
        } catch {
            state = .failed((error as NSError).localizedDescription)
            statusMessage = "실패: \((error as NSError).localizedDescription)"
        }
    }

    private func buildConfig() throws -> ScanConfig {
        let source: OpenAPISource
        switch sourceMode {
        case .url:
            guard let url = URL(string: openAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw NSError(domain: "StellaApp", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "유효하지 않은 OpenAPI URL"
                ])
            }
            let auth: BasicAuth?
            if !basicUser.isEmpty || !basicPass.isEmpty {
                auth = BasicAuth(user: basicUser, password: basicPass)
            } else {
                auth = nil
            }
            source = .url(url, auth: auth)
        case .file:
            let trimmed = openAPIFile.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw NSError(domain: "StellaApp", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "OpenAPI 파일을 선택하세요"
                ])
            }
            source = .file(absoluteURL(trimmed))
        }

        let blame = blameRoot.isEmpty
            ? Self.inferRepoRoot()
            : absoluteURL(blameRoot)

        var projects: [ProjectInput] = []
        if !appProductPath.isEmpty {
            let url = projectURL(appProductPath, blameRoot: blame)
            try validateDirectory(url, label: "AppProduct")
            projects.append(.appProduct(rootPath: url))
        }
        if !umcAppPath.isEmpty {
            let url = projectURL(umcAppPath, blameRoot: blame)
            try validateDirectory(url, label: "UMCApp")
            projects.append(.umcApp(rootPath: url))
        }
        guard !projects.isEmpty else {
            throw NSError(domain: "StellaApp", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "프로젝트 경로를 최소 한 개 이상 설정하세요"
            ])
        }
        try validateDirectory(blame, label: "Blame 루트")

        return ScanConfig(
            openAPISource: source,
            projects: projects,
            overridesURL: optionalFile(overridesPath),
            authorsURL: optionalFile(authorsPath),
            ownersURL: optionalFile(ownersPath),
            blameRoot: blame
        )
    }

    private func optionalFile(_ path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              FileManager.default.fileExists(atPath: trimmed) else { return nil }
        return absoluteURL(trimmed)
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

    private func validateDirectory(_ url: URL, label: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(domain: "StellaApp", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "\(label) 경로가 존재하지 않습니다: \(url.path)"
            ])
        }
    }

    private static func inferRepoRoot() -> URL {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
        var candidate = current

        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("AppProduct").path),
               FileManager.default.fileExists(atPath: candidate.appendingPathComponent("UMCApp").path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }

        return current
    }

    // MARK: - Filtered endpoints

    var availableTags: [String] {
        guard let snapshot else { return [] }
        let tags = snapshot.endpoints.compactMap { $0.tag }
        return Array(Set(tags)).sorted()
    }

    var availableOwners: [String] {
        let snapshotOwners = snapshot?.endpoints.compactMap { $0.owner?.displayName } ?? []
        let localOwners = manualOwners.map { $0.authorRef.displayName }
        return Array(Set(snapshotOwners + localOwners)).sorted()
    }

    var filteredEndpoints: [CoverageSnapshot.EndpointEntry] {
        guard let snapshot else { return [] }
        return snapshot.endpoints.filter { entry in
            if let methodFilter, entry.key.method != methodFilter { return false }
            if let selectedTag, entry.tag != selectedTag { return false }
            if let selectedOwner, entry.owner?.displayName != selectedOwner { return false }

            let matchedCount = entry.connections.values.compactMap { $0 }.count
            let totalProjects = entry.connections.count
            switch connectionFilter {
            case .all: break
            case .onlyMatched where matchedCount == totalProjects && totalProjects > 0: break
            case .onlyMissing where matchedCount == 0: break
            case .mixed where matchedCount > 0 && matchedCount < totalProjects: break
            case .onlyMatched, .onlyMissing, .mixed: return false
            }

            if !query.isEmpty {
                let q = query.lowercased()
                let pathHit = entry.key.path.lowercased().contains(q)
                let summaryHit = entry.summary?.lowercased().contains(q) ?? false
                let opIdHit = entry.operationId?.lowercased().contains(q) ?? false
                let ownerHit = entry.owner?.displayName.lowercased().contains(q) ?? false
                if !(pathHit || summaryHit || opIdHit || ownerHit) { return false }
            }
            return true
        }
    }

    // MARK: - Snapshot IO

    func openSnapshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            snapshot = applyingManualOwners(to: try SnapshotEncoder.decode(data))
            state = .loaded
            statusMessage = "\(url.lastPathComponent) 스냅샷을 불러왔어요"
        } catch {
            state = .failed((error as NSError).localizedDescription)
            statusMessage = "열기 실패: \((error as NSError).localizedDescription)"
        }
    }

    func saveSnapshot() {
        guard let snapshot else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "coverage.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try SnapshotEncoder.encode(snapshot)
            try data.write(to: url)
            statusMessage = "\(url.lastPathComponent)에 저장했어요"
        } catch {
            statusMessage = "저장 실패: \((error as NSError).localizedDescription)"
        }
    }

    var canExportOwnersYAML: Bool {
        !ownerAssignments.isEmpty
    }

    func saveOwnersYAML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.yaml, .data]
        panel.nameFieldStringValue = "owners.yml"
        if !ownersPath.isEmpty {
            let existing = URL(fileURLWithPath: ownersPath)
            panel.directoryURL = existing.deletingLastPathComponent()
            panel.nameFieldStringValue = existing.lastPathComponent
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportOwnersYAML(to: url)
            ownersPath = url.path
            persistDefaults()
            statusMessage = "\(url.lastPathComponent)에 담당자를 저장했어요"
        } catch {
            statusMessage = "owners.yml 저장 실패: \((error as NSError).localizedDescription)"
        }
    }

    private func exportOwnersYAML(to url: URL) throws {
        var existingTagOwners: [String: String] = [:]
        if FileManager.default.fileExists(atPath: url.path),
           let existing = try? OwnersLoader.load(from: url) {
            existingTagOwners = existing.tagOwners
        }

        var endpointOwners: [OpenAPIKey: String] = [:]
        for (id, email) in ownerAssignments {
            let parts = id.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let method = HTTPMethod(rawValue: parts[0])
            else { continue }
            endpointOwners[OpenAPIKey(method: method, path: parts[1])] = email
        }

        let merged = Owners(tagOwners: existingTagOwners, endpointOwners: endpointOwners)
        let header = """
        # Auto-generated by Stella. Endpoint 매핑은 GUI 변경 시 덮어써집니다.
        # tags 섹션은 보존되니 수동 편집 가능합니다.

        """
        let yaml = header + OwnersLoader.serialize(merged)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - File pickers

    func pickFile(into binding: ReferenceWritableKeyPath<ScanModel, String>, types: [NSPasteboard.PasteboardType.RawValue] = []) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            self[keyPath: binding] = url.path
        }
    }

    func pickDirectory(into binding: ReferenceWritableKeyPath<ScanModel, String>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            self[keyPath: binding] = url.path
        }
    }

    // MARK: - Owners

    func upsertOwner(_ owner: EditableOwner) {
        var next = owner
        next.email = owner.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.email.isEmpty else { return }

        if let index = manualOwners.firstIndex(where: { $0.email == next.email }) {
            manualOwners[index] = next
        } else {
            manualOwners.append(next)
        }
        manualOwners.sort { $0.authorRef.displayName < $1.authorRef.displayName }
        persistDefaults()
        if let snapshot {
            self.snapshot = applyingManualOwners(to: snapshot)
        }
    }

    func deleteOwner(_ owner: EditableOwner) {
        manualOwners.removeAll { $0.email == owner.email }
        ownerAssignments = ownerAssignments.filter { $0.value != owner.email }
        persistDefaults()
        if let snapshot {
            self.snapshot = applyingManualOwners(to: snapshot)
        }
    }

    func assignOwner(email: String?, to entry: CoverageSnapshot.EndpointEntry) {
        if let email, !email.isEmpty {
            ownerAssignments[endpointID(entry)] = email
        } else {
            ownerAssignments.removeValue(forKey: endpointID(entry))
        }
        persistDefaults()
        if let snapshot {
            self.snapshot = applyingManualOwners(to: snapshot)
        }
    }

    func assignedOwnerEmail(for entry: CoverageSnapshot.EndpointEntry) -> String? {
        ownerAssignments[endpointID(entry)] ?? entry.owner?.email
    }

    func endpointID(_ entry: CoverageSnapshot.EndpointEntry) -> String {
        "\(entry.key.method.rawValue) \(entry.key.path)"
    }

    private func applyingManualOwners(to snapshot: CoverageSnapshot) -> CoverageSnapshot {
        var reconciled = ownerAssignments
        for entry in snapshot.endpoints {
            if let yamlEmail = entry.owner?.email {
                reconciled[endpointID(entry)] = yamlEmail
            }
        }
        if reconciled != ownerAssignments {
            ownerAssignments = reconciled
            persistDefaults()
        }

        let ownersByEmail = Dictionary(uniqueKeysWithValues: manualOwners.map { ($0.email, $0.authorRef) })
        let endpoints = snapshot.endpoints.map { entry in
            let assignedEmail = ownerAssignments[endpointID(entry)]
            let owner = assignedEmail.flatMap { ownersByEmail[$0] } ?? entry.owner
            return CoverageSnapshot.EndpointEntry(
                key: entry.key,
                tag: entry.tag,
                operationId: entry.operationId,
                summary: entry.summary,
                description: entry.description,
                parameters: entry.parameters,
                requestBody: entry.requestBody,
                requestBodyExample: entry.requestBodyExample,
                responses: entry.responses,
                owner: owner,
                connections: entry.connections
            )
        }

        return CoverageSnapshot(
            schemaVersion: snapshot.schemaVersion,
            generatedAt: snapshot.generatedAt,
            openAPI: snapshot.openAPI,
            projects: snapshot.projects,
            endpoints: endpoints,
            unmatchedRouterCases: snapshot.unmatchedRouterCases,
            summary: snapshot.summary
        )
    }

    // MARK: - API test

    func runAPITest(entry: CoverageSnapshot.EndpointEntry) async {
        persistDefaults()
        isAPITestRunning = true
        apiResponseText = ""
        defer { isAPITestRunning = false }

        do {
            let request = try makeAPIRequest(entry: entry)
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse).map { "\($0.statusCode)" } ?? "?"
            let body = formattedResponseBody(data)
            apiResponseText = "HTTP \(status)\n\n\(body)"
        } catch {
            apiResponseText = "실패: \((error as NSError).localizedDescription)"
        }
    }

    private func formattedResponseBody(_ data: Data) -> String {
        guard !data.isEmpty else { return "<empty body>" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object),
           let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
           ),
           let pretty = String(data: prettyData, encoding: .utf8) {
            return pretty
        }
        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    func prepareAPITestTemplate(for entry: CoverageSnapshot.EndpointEntry, overwrite: Bool = false) {
        let pathFs = pathFields(for: entry)
        let queryFs = queryFields(for: entry)

        if overwrite || apiPathValues.isEmpty {
            apiPathValues = Dictionary(uniqueKeysWithValues: pathFs.map {
                ($0.name, placeholderValue(name: $0.name, schema: $0.type))
            })
        }
        if overwrite || apiQueryValues.isEmpty {
            apiQueryValues = Dictionary(uniqueKeysWithValues: queryFs.map {
                ($0.name, placeholderValue(name: $0.name, schema: $0.type))
            })
        }
        if overwrite || apiRequestBody.isEmpty {
            apiRequestBody = entry.requestBodyExample ?? ""
        }
        apiResponseText = ""
    }

    func pathFields(for entry: CoverageSnapshot.EndpointEntry) -> [APIParameterField] {
        var seen = Set<String>()
        var result: [APIParameterField] = []

        for param in entry.parameters where param.location == "path" {
            if seen.insert(param.name).inserted {
                result.append(APIParameterField(
                    name: param.name,
                    location: "path",
                    type: param.schema,
                    required: param.required,
                    description: param.description
                ))
            }
        }

        let pattern = #"\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = entry.key.path as NSString
            for match in regex.matches(in: entry.key.path, range: NSRange(location: 0, length: ns.length)) {
                let name = ns.substring(with: match.range(at: 1))
                if seen.insert(name).inserted {
                    result.append(APIParameterField(
                        name: name,
                        location: "path",
                        type: nil,
                        required: true,
                        description: nil
                    ))
                }
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    func queryFields(for entry: CoverageSnapshot.EndpointEntry) -> [APIParameterField] {
        entry.parameters
            .filter { $0.location == "query" }
            .sorted {
                if $0.required != $1.required { return $0.required && !$1.required }
                return $0.name < $1.name
            }
            .map {
                APIParameterField(
                    name: $0.name,
                    location: "query",
                    type: $0.schema,
                    required: $0.required,
                    description: $0.description
                )
            }
    }

    private func makeAPIRequest(entry: CoverageSnapshot.EndpointEntry) throws -> URLRequest {
        guard var components = URLComponents(string: apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "StellaApp", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "API Base URL이 올바르지 않습니다."
            ])
        }

        var path = entry.key.path
        for (key, value) in apiPathValues {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            path = path.replacingOccurrences(of: "{\(key)}", with: trimmed)
        }
        components.path = path

        let queryItems = apiQueryValues.compactMap { (key, value) -> URLQueryItem? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return URLQueryItem(name: key, value: trimmed)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems.sorted { $0.name < $1.name }
        }

        guard let url = components.url else {
            throw NSError(domain: "StellaApp", code: 21, userInfo: [
                NSLocalizedDescriptionKey: "요청 URL을 만들 수 없습니다."
            ])
        }

        var request = URLRequest(url: url)
        request.httpMethod = entry.key.method.rawValue
        if !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if !apiRequestBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.httpBody = Data(apiRequestBody.utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func placeholderValue(name: String, schema: String? = nil) -> String {
        let lowered = name.lowercased()
        if lowered.contains("id") { return "1" }
        if lowered.contains("page") || lowered.contains("cursor") { return "0" }
        if lowered.contains("size") || lowered.contains("limit") { return "20" }
        if schema == "integer" || schema == "number" { return "0" }
        if schema == "boolean" { return "false" }
        return "string"
    }

    // MARK: - Helpers

    func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
