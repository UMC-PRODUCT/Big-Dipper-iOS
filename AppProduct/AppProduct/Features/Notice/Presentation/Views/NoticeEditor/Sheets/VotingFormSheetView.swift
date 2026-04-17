//
//  VotingFormSheetView.swift
//  AppProduct
//
//  Created by 이예지 on 1/28/26.
//

import SwiftUI

/// 투표 생성/수정 폼 시트
///
/// 제목, 항목(2~5개), 익명/복수선택 토글, 시작/마감일 설정을 제공합니다.
struct VotingFormSheetView: View, Equatable {

    // MARK: - Property
    /// 투표 폼 데이터 바인딩
    @Binding var formData: VoteFormData
    /// 취소 액션
    var onCancel: () -> Void
    /// 확인 액션
    var onConfirm: () -> Void
    /// 시트 모드(생성/수정)
    var mode: VoteEditorMode = .create
    
    /// 확인 버튼 로컬 로딩 상태
    @State private var isSubmitting: Bool = false
    
    /// DEBUG 런치 인자로 강제 로딩 상태를 표시합니다.
    @State private var isDebugLoading: Bool = false

    /// 투표 에디터 모드
    enum VoteEditorMode {
        case create
        case edit
    }
    
    // MARK: - Constants
    fileprivate enum Constants {
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

    /// 스크롤 본문 콘텐츠
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

    /// 상단 툴바 액션(취소/확인)
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

    /// 모드에 따른 네비게이션 타이틀
    private var navigationTitle: NavigationModifier.Navititle {
        mode == .create ? .voteCreate : .voteEdit
    }
    
    // MARK: - Title Section
    /// 투표 제목 입력 섹션
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
    /// 투표 항목 입력 섹션
    private var optionsSection: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            ForEach($formData.options) { $option in
                optionRow(option: $option)
                    .transition(Constants.optionsTransition)
            }
        }
    }

    /// 단일 투표 항목 행
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
    /// 항목 추가 버튼
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
    /// 익명/복수선택 토글 섹션
    private var toggleSection: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            toggleItem(title: Constants.anonymousVoteTitle, isOn: $formData.isAnonymous)
            toggleItem(title: Constants.allowMultipleSelectionTitle, isOn: $formData.allowMultipleSelection)
        }
        .padding(.top, Constants.toggleTopMargin)
    }

    /// 토글 공통 행
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
    /// 투표 시작일/마감일 섹션
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

    /// 날짜 선택 공통 행
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
    /// 현재 옵션의 인덱스를 반환합니다.
    private func optionIndex(for option: VoteOptionItem) -> Int {
        formData.options.firstIndex(where: { $0.id == option.id }) ?? 0
    }

    /// 최소 옵션 개수(2개) 이후부터 삭제 버튼 노출
    private func canDeleteOption(at index: Int) -> Bool {
        index >= VoteFormData.minOptionCount
    }

    /// 새 옵션을 추가합니다.
    private func addOption() {
        guard formData.canAddOption else { return }
        formData.options.append(VoteOptionItem())
    }

    /// 선택한 옵션을 제거합니다.
    private func removeOption(_ option: VoteOptionItem) {
        guard formData.canRemoveOption else { return }
        formData.options.removeAll { $0.id == option.id }
    }

    // MARK: - Date Binding

    /// 시작일 바인딩(선택일 00:00:00 고정)
    private var startDateBinding: Binding<Date> {
        Binding(
            get: { formData.startDate },
            set: { newDate in
                formData.startDate = Calendar.current.startOfDay(for: newDate)
            }
        )
    }

    /// 마감일 바인딩(선택일 23:59:59 고정)
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

    /// 마감일 최소 허용값(시작일 + 1일)
    private var endDateLowerBound: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: formData.startDate) ?? formData.startDate
    }
    
    /// 확인 버튼 로딩 상태(실제 제출 + DEBUG 강제 상태)
    private var isConfirmButtonLoading: Bool {
        isSubmitting || isDebugLoading
    }
    
    /// 확인 버튼 탭 처리
    private func handleConfirmTap() {
        guard !isConfirmButtonLoading else { return }
        isSubmitting = true
        onConfirm()
        
        Task { @MainActor in
            // 시트가 즉시 닫히지 않는 경우를 대비해 다음 프레임에 로딩 상태 복구
            await Task.yield()
            isSubmitting = false
        }
    }
    
    /// DEBUG 런치 인자로 투표 시트 툴바 로딩 상태를 강제 표시합니다.
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
