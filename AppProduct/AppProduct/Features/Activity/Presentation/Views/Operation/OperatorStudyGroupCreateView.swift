//
//  OperatorStudyGroupCreateView.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/11/26.
//

import SwiftUI

/// 스터디 그룹 생성 화면
///
/// 운영진이 새로운 스터디 그룹을 생성하는 폼 화면입니다.
/// `navigationDestination`으로 푸시되므로 자체 `NavigationStack` 없음.
struct OperatorStudyGroupCreateView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @FocusState private var isNameFocused: Bool
    @State private var selectedPart: UMCPartType?
    @State private var selectedLeader: [ChallengerInfo] = []
    @State private var selectedMembers: [ChallengerInfo] = []
    @State private var fixedLeader: ChallengerInfo?

    @State private var showLeaderSheet = false
    @State private var showMemberSheet = false
    @State private var isSaving = false

    private let viewModel: OperatorStudyManagementViewModel

    private var alertPromptBinding: Binding<AlertPrompt?> {
        Binding(
            get: { viewModel.alertPrompt },
            set: { viewModel.alertPrompt = $0 }
        )
    }

    init(viewModel: OperatorStudyManagementViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let allParts: [UMCPartType] = UMCPartType.allCases
        static let participantText: String = "초대받은 스터디원"
        static let chevronImage: String = "chevron.right"
        static let leaderPlaceholderText: String = "담당 파트장을 선택하세요"
        static let groupNamePlaceholder: String = "그룹 이름 지정"
        static let groupNameGuideText: String = "예: React 실습 A팀"
        static let groupNameMaxLength: Int = 20
        static let partHeaderText: String = "해당 파트"
        static let partText: String = "파트"
        static let partPlaceholderText: String = "파트를 선택하세요"
    }

    // MARK: - Body

    var body: some View {
        Form {
            nameSection
            partAndLeaderSection
            memberSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("스터디 그룹 생성")
        .navigationBarTitleDisplayMode(.inline)
        .alertPrompt(item: alertPromptBinding)
        .toolbar {
            ToolBarCollection.AddBtn(
                action: { save() },
                disable: !isValid,
                isLoading: isSaving,
                dismissOnTap: false
            )
        }
        .sheet(isPresented: $showLeaderSheet) {
            SelectedChallengerView(challenger: $selectedLeader)
                .interactiveDismissDisabled()
        }
        .onChange(of: showLeaderSheet) { _, isPresented in
            guard !isPresented else { return }
            if let fixedLeader {
                selectedLeader = [fixedLeader]
                return
            }
            if !isPresented, selectedLeader.count > 1 {
                selectedLeader = [selectedLeader[0]]
            }
            if let first = selectedLeader.first {
                fixedLeader = first
            }
        }
        .sheet(isPresented: $showMemberSheet) {
            SelectedChallengerView(challenger: $selectedMembers)
                .interactiveDismissDisabled()
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            nameInputSection
        }
    }

    private var partAndLeaderSection: some View {
        Section {
            partSection
            leaderRow
        }
    }

    private var partSection: some View {
        Picker(selection: $selectedPart) {
            Text(Constants.partPlaceholderText)
                .tag(nil as UMCPartType?)

            ForEach(Constants.allParts, id: \.self) { part in
                Label(part.name, systemImage: part.icon)
                    .tint(part.color)
                    .tag(Optional(part))
            }
        } label: {
            Text(Constants.partText)
                .appFont(.subheadline, color: .black)
        }
        .pickerStyle(.menu)
    }

    private var memberSection: some View {
        Section {
            memberRow
        }
    }

    // MARK: - Rows

    private var leaderRow: some View {
        selectionButton(
            title: selectedLeaderText,
            titleColor: .black,
            countText: selectedLeaderCountText,
            isPlaceholder: selectedLeader.isEmpty
        ) {
            showLeaderSheet = true
        }
    }

    private var memberRow: some View {
        selectionButton(
            title: Constants.participantText,
            titleColor: .black,
            countText: selectedMembersCountText
        ) {
            showMemberSheet = true
        }
    }

    // MARK: - Function

    private var selectedLeaderText: String {
        selectedLeader.first.flatMap { "\($0.nickname)/\($0.name)" }
            ?? Constants.leaderPlaceholderText
    }

    private var selectedLeaderCountText: String? {
        selectedLeader.isEmpty ? nil : "1명"
    }

    private var selectedMembersCountText: String? {
        selectedMembers.isEmpty ? nil : "\(selectedMembers.count)명"
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && selectedPart != nil
            && !selectedLeader.isEmpty
            && !selectedMembers.isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var nameLengthText: String {
        "\(name.count)/\(Constants.groupNameMaxLength)자"
    }

    private func save() {
        guard !isSaving else { return }
        guard let leader = selectedLeader.first,
              let selectedPart,
              !selectedMembers.isEmpty
        else { return }

        print("save start")
        print("raw name count:", name.count)
        print("leader memberId:", leader.memberId)
        print("members count:", selectedMembers.count)

        let nameToSave = NSString(string: trimmedName) as String
        let partToSave = selectedPart
        let leaderToSave = leader
        let membersToSave = selectedMembers

        print("save snapshot ready")
        print("trimmed name count:", nameToSave.count)

        Task { @MainActor in
            print("save task start")
            isSaving = true
            let didSave = await viewModel.createGroup(
                name: nameToSave,
                part: partToSave,
                leader: leaderToSave,
                members: membersToSave
            )
            print("save task finished:", didSave)
            isSaving = false

            if didSave {
                dismiss()
            }
        }
    }

    private func selectionButton(
        title: String,
        titleColor: Color,
        countText: String? = nil,
        isPlaceholder: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .appFont(
                        .subheadline,
                        color: isPlaceholder ? .grey400 : titleColor
                    )
                Spacer()

                HStack(spacing: DefaultSpacing.spacing8) {
                    if let countText {
                        Text(countText)
                            .appFont(.callout, color: .grey500)
                    }

                    Image(systemName: Constants.chevronImage)
                        .foregroundStyle(.grey500)
                }
            }
        }
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack(spacing: DefaultSpacing.spacing8) {
                nameInputField
                clearNameButton
                nameLengthLabel
            }

            Text(Constants.groupNameGuideText)
                .appFont(.footnote, color: .grey500)
        }
    }

    private var nameInputField: some View {
        TextField(
            Constants.groupNamePlaceholder,
            text: $name
        )
        .focused($isNameFocused)
        .onChange(of: name) { _, newValue in
            enforceNameMaxLength(newValue)
        }
        .submitLabel(.next)
        .appFont(.subheadline)
    }

    private var clearNameButton: some View {
        Group {
            if !name.isEmpty {
                Button {
                    name = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.grey400)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nameLengthLabel: some View {
        Text(nameLengthText)
            .appFont(.footnote, color: .grey500)
    }

    private func enforceNameMaxLength(_ text: String) {
        guard text.count > Constants.groupNameMaxLength else { return }
        name = String(text.prefix(Constants.groupNameMaxLength))
    }
}
