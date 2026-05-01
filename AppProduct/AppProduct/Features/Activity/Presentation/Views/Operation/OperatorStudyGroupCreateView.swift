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
    @State private var selectedMentors: [ChallengerInfo] = []
    @State private var selectedMembers: [ChallengerInfo] = []

    @State private var showMentorSheet = false
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
        static let mentorText: String = "담당 파트장(멘토)"
        static let chevronImage: String = "chevron.right"
        static let mentorPlaceholderText: String = "담당 파트장(멘토)을 선택하세요 (1명 이상)"
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
            generationSection
            nameSection
            partAndMentorSection
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
        .sheet(isPresented: $showMentorSheet) {
            SelectedChallengerView(challenger: $selectedMentors)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showMemberSheet) {
            SelectedChallengerView(challenger: $selectedMembers)
                .interactiveDismissDisabled()
        }
    }

    // MARK: - Sections

    private var generationSection: some View {
        Section {
            HStack {
                Text("기수")
                    .appFont(.subheadline, color: .grey700)
                Spacer()
                Text(generationDisplayText)
                    .appFont(.subheadline, color: .grey900)
            }
        }
    }

    private var nameSection: some View {
        Section {
            nameInputSection
        }
    }

    private var partAndMentorSection: some View {
        Section {
            partSection
            mentorRow
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
                .appFont(.subheadline, color: .grey900)
        }
        .pickerStyle(.menu)
    }

    private var memberSection: some View {
        Section {
            memberRow
        }
    }

    // MARK: - Rows

    private var mentorRow: some View {
        selectionButton(
            title: selectedMentorsText,
            titleColor: .grey900,
            countText: selectedMentorsCountText,
            isPlaceholder: selectedMentors.isEmpty
        ) {
            showMentorSheet = true
        }
        .accessibilityLabel(Constants.mentorText)
    }

    private var memberRow: some View {
        selectionButton(
            title: Constants.participantText,
            titleColor: .grey900,
            countText: selectedMembersCountText
        ) {
            showMemberSheet = true
        }
    }

    // MARK: - Function

    private var generationDisplayText: String {
        let gisuId = viewModel.currentGisuId
        guard gisuId > 0 else { return "정보 없음" }
        return "\(gisuId)기"
    }

    private var selectedMentorsText: String {
        if selectedMentors.isEmpty {
            return Constants.mentorPlaceholderText
        }
        if selectedMentors.count == 1, let only = selectedMentors.first {
            return "\(only.nickname)/\(only.name)"
        }
        return Constants.mentorText
    }

    private var selectedMentorsCountText: String? {
        selectedMentors.isEmpty ? nil : "\(selectedMentors.count)명"
    }

    private var selectedMembersCountText: String? {
        selectedMembers.isEmpty ? nil : "\(selectedMembers.count)명"
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
            && selectedPart != nil
            && !selectedMentors.isEmpty
            && !selectedMembers.isEmpty
            && viewModel.currentGisuId > 0
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var nameLengthText: String {
        "\(name.count)/\(Constants.groupNameMaxLength)자"
    }

    private func save() {
        guard !isSaving else { return }
        guard let selectedPart,
              !selectedMentors.isEmpty,
              !selectedMembers.isEmpty
        else { return }

        let nameToSave = NSString(string: trimmedName) as String
        let partToSave = selectedPart
        let mentorsToSave = selectedMentors
        let membersToSave = selectedMembers

        Task { @MainActor in
            isSaving = true
            let didSave = await viewModel.createGroup(
                name: nameToSave,
                part: partToSave,
                mentors: mentorsToSave,
                members: membersToSave
            )
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
