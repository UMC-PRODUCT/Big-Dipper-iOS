import SwiftUI

struct ScanFormView: View {
    @Bindable var model: ScanModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                openAPISection
                Divider()
                apiRuntimeSection
                Divider()
                projectsSection
                Divider()
                metadataSection
                Divider()
                OwnerManagerView(model: model)
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var openAPISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAPI 소스").font(.title3).bold()
            Picker("모드", selection: $model.sourceMode) {
                ForEach(SourceMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.sourceMode {
            case .url:
                LabeledContent("URL") {
                    TextField("https://…", text: $model.openAPIURL)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Basic 인증") {
                    HStack {
                        TextField("사용자", text: $model.basicUser)
                            .textFieldStyle(.roundedBorder)
                        SecureField("비밀번호", text: $model.basicPass)
                            .textFieldStyle(.roundedBorder)
                        Button("저장") { model.persistDefaults() }
                    }
                }
            case .file:
                LabeledContent("파일") {
                    HStack {
                        TextField("/path/to/openapi.json", text: $model.openAPIFile)
                            .textFieldStyle(.roundedBorder)
                        Button("선택…") {
                            model.pickFile(into: \.openAPIFile)
                        }
                    }
                }
            }
        }
    }

    private var apiRuntimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API 테스트").font(.title3).bold()
            LabeledContent("Base URL") {
                TextField("https://dev.api.umc.it.kr", text: $model.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Bearer 토큰") {
                HStack {
                    SecureField("로그인 후 발급받은 access token", text: $model.bearerToken)
                        .textFieldStyle(.roundedBorder)
                    Button("저장") { model.persistDefaults() }
                }
            }
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("프로젝트").font(.title3).bold()
            pathRow(label: "AppProduct", binding: $model.appProductPath, key: \.appProductPath)
            pathRow(label: "UMCApp", binding: $model.umcAppPath, key: \.umcAppPath)
            pathRow(label: "Blame 루트", binding: $model.blameRoot, key: \.blameRoot)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("매핑 (선택)").font(.title3).bold()
            fileRow(label: "authors.yml", binding: $model.authorsPath, key: \.authorsPath)
            fileRow(label: "overrides.yml", binding: $model.overridesPath, key: \.overridesPath)
            fileRow(label: "owners.yml", binding: $model.ownersPath, key: \.ownersPath)
        }
    }

    private func pathRow(
        label: String,
        binding: Binding<String>,
        key: ReferenceWritableKeyPath<ScanModel, String>
    ) -> some View {
        LabeledContent(label) {
            HStack {
                TextField("/path/to/folder", text: binding)
                    .textFieldStyle(.roundedBorder)
                Button("선택…") { model.pickDirectory(into: key) }
            }
        }
    }

    private func fileRow(
        label: String,
        binding: Binding<String>,
        key: ReferenceWritableKeyPath<ScanModel, String>
    ) -> some View {
        LabeledContent(label) {
            HStack {
                TextField("/path/to/file.yml", text: binding)
                    .textFieldStyle(.roundedBorder)
                Button("선택…") { model.pickFile(into: key) }
            }
        }
    }
}

private struct OwnerManagerView: View {
    @Bindable var model: ScanModel
    @State private var draft = EditableOwner(email: "", displayName: "", githubUsername: "")
    @State private var selection: EditableOwner.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("담당자").font(.title3).bold()
                Spacer()
                Button("새 담당자") {
                    selection = nil
                    draft = EditableOwner(email: "", displayName: "", githubUsername: "")
                }
            }

            HStack(alignment: .top, spacing: 16) {
                List(model.manualOwners, selection: $selection) { owner in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(owner.authorRef.displayName)
                        Text(owner.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(owner.id)
                }
                .frame(width: 260, height: 180)
                .onChange(of: selection) { _, newValue in
                    if let newValue,
                       let owner = model.manualOwners.first(where: { $0.id == newValue }) {
                        draft = owner
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("email", text: $draft.email)
                        .textFieldStyle(.roundedBorder)
                    TextField("표시 이름", text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                    TextField("GitHub username", text: $draft.githubUsername)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("저장") {
                            model.upsertOwner(draft)
                            selection = draft.id
                        }
                        .disabled(draft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("삭제", role: .destructive) {
                            if let selection,
                               let owner = model.manualOwners.first(where: { $0.id == selection }) {
                                model.deleteOwner(owner)
                                self.selection = nil
                                draft = EditableOwner(email: "", displayName: "", githubUsername: "")
                            }
                        }
                        .disabled(selection == nil)
                    }
                }
                .frame(maxWidth: 360)
            }
        }
    }
}
