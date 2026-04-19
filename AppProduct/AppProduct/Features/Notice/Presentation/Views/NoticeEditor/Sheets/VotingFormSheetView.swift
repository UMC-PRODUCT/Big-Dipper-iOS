//
//  VotingFormSheetView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

struct VotingFormSheetView: View, Equatable {

    // MARK: - Property

    @Binding var formData: VoteFormData
    var onCancel: () -> Void
    var onConfirm: () -> Void
    var mode: VoteEditorMode = .create

    @State private var isSubmitting: Bool = false
    @State private var isDebugLoading: Bool = false

    enum VoteEditorMode {
        case create
        case edit
    }
    
    // MARK: - Constants

    private enum Constants {
        static let titlePlaceholder: String = "투표 제목을 입력하세요"
        static let optionPlaceholderPrefix: String = "항목 "
        static let addOptionTitle: String = "항목 추가"
        static let addOptionIcon: String = "plus"
        static let anonymousVoteTitle: String = "익명 투표"
        static let allowMultipleSelectionTitle: String = "복수 선택 허용"
        static let voteStartDateTitle: String = "투표 시작일"
        static let voteEndDateTitle: String = "투표 마감일"
        static let trashIcon: String = "trash"

        static let optionsTransition: AnyTransition = .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )

        static let addOptionStrokeStyle: StrokeStyle = StrokeStyle(lineWidth: 1, dash: [7])
        static let questionBottomMargin: CGFloat = 4
        static let trashSize: CGFloat = 16
        static let trashPadding: CGFloat = 12
        static let optionHPadding: CGFloat = 8
        static let toggleTopMargin: CGFloat = 16
        static let dateTopMargin: CGFloat = 4
        static let contentBottomPadding: CGFloat = DefaultSpacing.spacing24
        static let debugLoadingArgument: String = "--debug-vote-editor-loading"
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.formData == rhs.formData
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                contentView
            }
            .scrollDismissesKeyboard(.immediately)
            .navigation(naviTitle: navigationTitle, displayMode: .inline)
            .toolbar { toolbarContent }
            .task { applyDebugLoadingStateIfNeeded() }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            titleSection
            optionsSection
            if formData.canAddOption {
                addOptionButton
            }
            toggleSection
            dateSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.top, DefaultConstant.defaultContentTopMargins)
        .padding(.bottom, Constants.contentBottomPadding)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolBarCollection.CancelBtn(action: onCancel)
        
        if mode == .create {
            ToolBarCollection.AddBtn(
                action: handleConfirmTap,
                disable: !formData.canConfirm,
                isLoading: isConfirmButtonLoading,
                dismissOnTap: false
            )
        } else {
            ToolBarCollection.ConfirmBtn(
                action: handleConfirmTap,
                disable: !formData.canConfirm,
                isLoading: isConfirmButtonLoading,
                dismissOnTap: false
            )
        }
    }

    private var navigationTitle: NavigationModifier.Navititle {
        mode == .create ? .voteCreate : .voteEdit
    }
    
    // MARK: - Title Section

    private var titleSection: some View {
        VStack {
            TextField(
                "",
                text: $formData.title,
                prompt: Text(Constants.titlePlaceholder)
            )
            .appFont(.calloutEmphasis)
            .padding(.horizontal, Constants.optionHPadding)
            
            Divider()
        }
        .padding(.bottom, Constants.questionBottomMargin)
    }
    
    // MARK: - Options

    private var optionsSection: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            ForEach($formData.options) { $option in
                optionRow(option: $option)
                    .transition(Constants.optionsTransition)
            }
        }
    }

    private func optionRow(option: Binding<VoteOptionItem>) -> some View {
        let index = optionIndex(for: option.wrappedValue)

        return HStack(spacing: DefaultSpacing.spacing8) {
            TextField(
                "",
                text: option.text,
                prompt: Text("\(Constants.optionPlaceholderPrefix)\(index + 1)")
            )
            .appFont(.callout)
            .padding(DefaultConstant.defaultTextFieldPadding)
            
            if canDeleteOption(at: index) {
                Button {
                    removeOption(option.wrappedValue)
                } label: {
                    Image(systemName: Constants.trashIcon)
                        .font(.system(size: Constants.trashSize))
                        .foregroundStyle(.red)
                        .padding(Constants.trashPadding)
                }
            }
        }
        .padding(.horizontal, Constants.optionHPadding)
        .background {
            RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                .fill(.grey100)
        }
    }

    // MARK: - Add Option Button

    private var addOptionButton: some View {
        Button {
            addOption()
        } label: {
            Label(Constants.addOptionTitle, systemImage: Constants.addOptionIcon)
                .appFont(.callout, color: .black)
                .frame(maxWidth: .infinity)
                .padding(DefaultConstant.defaultTextFieldPadding)
                .background {
                    RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                        .fill(.clear)
                        .strokeBorder(.grey300, style: Constants.addOptionStrokeStyle)
                }
        }
        .disabled(!formData.canAddOption)
    }

    // MARK: - Toggle Section

    private var toggleSection: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            toggleItem(title: Constants.anonymousVoteTitle, isOn: $formData.isAnonymous)
            toggleItem(title: Constants.allowMultipleSelectionTitle, isOn: $formData.allowMultipleSelection)
        }
        .padding(.top, Constants.toggleTopMargin)
    }

    private func toggleItem(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(title)
                .appFont(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.indigo500)
        }
    }
    
    // MARK: - Date Section

    private var dateSection: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            dateRow(
                title: Constants.voteStartDateTitle,
                selection: startDateBinding,
                range: Date()...Date.distantFuture
            )
            dateRow(
                title: Constants.voteEndDateTitle,
                selection: endDateBinding,
                range: endDateLowerBound...Date.distantFuture
            )
        }
        .padding(.top, Constants.dateTopMargin)
    }

    private func dateRow(
        title: String,
        selection: Binding<Date>,
        range: ClosedRange<Date>
    ) -> some View {
        HStack {
            Text(title)
                .appFont(.subheadline)

            Spacer()

            DatePicker(
                "",
                selection: selection,
                in: range,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
        }
    }

    // MARK: - Function

    private func optionIndex(for option: VoteOptionItem) -> Int {
        formData.options.firstIndex(where: { $0.id == option.id }) ?? 0
    }

    private func canDeleteOption(at index: Int) -> Bool {
        index >= VoteFormData.minOptionCount
    }

    private func addOption() {
        guard formData.canAddOption else { return }
        formData.options.append(VoteOptionItem())
    }

    private func removeOption(_ option: VoteOptionItem) {
        guard formData.canRemoveOption else { return }
        formData.options.removeAll { $0.id == option.id }
    }

    // MARK: - Date Binding

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { formData.startDate },
            set: { newDate in
                formData.startDate = Calendar.current.startOfDay(for: newDate)
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { formData.endDate },
            set: { newDate in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: newDate)
                formData.endDate = calendar.date(
                    bySettingHour: 23,
                    minute: 59,
                    second: 59,
                    of: startOfDay
                ) ?? newDate
            }
        )
    }

    private var endDateLowerBound: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: formData.startDate) ?? formData.startDate
    }
    
    private var isConfirmButtonLoading: Bool {
        isSubmitting || isDebugLoading
    }

    private func handleConfirmTap() {
        guard !isConfirmButtonLoading else { return }
        isSubmitting = true
        onConfirm()

        Task { @MainActor in
            // 시트가 즉시 닫히지 않을 경우를 대비해 다음 프레임에 로딩 상태를 복구합니다.
            await Task.yield()
            isSubmitting = false
        }
    }

    private func applyDebugLoadingStateIfNeeded() {
        #if DEBUG
        isDebugLoading = ProcessInfo.processInfo.arguments.contains(Constants.debugLoadingArgument)
        #endif
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var formData = VoteFormData()
    
    NavigationStack {
        VotingFormSheetView(
            formData: $formData,
            onCancel: {
                formData = VoteFormData()
                print("취소됨")
            },
            onConfirm: {
                print("저장됨: \(formData)")
            }
        )
    }
}
