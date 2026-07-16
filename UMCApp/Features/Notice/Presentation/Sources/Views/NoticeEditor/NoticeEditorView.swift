//
//  NoticeEditorView.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import PhotosUI
import SwiftData
import UMCFoundation
import CoreDI
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

/// 공지사항 작성/수정 에디터 화면
///
/// 카테고리 선택, 제목/본문 입력, 이미지/링크/투표 첨부를 지원합니다.
public struct NoticeEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorHandler.self) private var errorHandler

    /// 사용자 조직 타입 (중앙/지부/학교)
    @AppStorage(AppStorageKey.organizationType) private var organizationType: String = ""

    /// 사용자 지부명
    @AppStorage(AppStorageKey.chapterName) private var chapterName: String = ""

    /// 사용자 학교명
    @AppStorage(AppStorageKey.schoolName) private var schoolName: String = ""

    /// 사용자 기수 ID
    @AppStorage(AppStorageKey.gisuId) private var gisuId: String = ""

    /// 사용자 지부 ID
    @AppStorage(AppStorageKey.chapterId) private var chapterId: String = ""

    /// 사용자 역할
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""

    @State private var viewModel: NoticeEditorViewModel
    private let selectedGisuId: String?

    /// 링크 추가 직후 자동 스크롤/포커스에 사용할 링크 ID
    @State private var newlyAddedLinkID: UUID?

    /// 사진 첨부 피커 노출 여부
    @State private var isPhotoPickerPresented = false

    /// 현재 선택된 형광펜 색상 (.none = 비활성)
    @State private var selectedHighlightColor: HighlightColor = .none

    /// 제목/내용 입력 포커스 제어
    @FocusState private var isTitleFieldFocused: Bool
    @FocusState private var isContentFieldFocused: Bool

    /// ScrollView 높이 (본문 영역이 남은 공간을 채우기 위해 사용)
    @State private var scrollViewHeight: CGFloat = 0

    /// 본문이 화면을 꽉 채우도록 최소 높이 계산
    private var editorMinHeight: CGFloat {
        max(scrollViewHeight, Constants.editorMinHeight)
    }

    // MARK: - Initializer

    public init(
        container: DIContainer,
        mode: NoticeEditorMode = .create,
        selectedGisuId: String? = nil,
        initialCategory: EditorMainCategory? = nil
    ) {
        self.selectedGisuId = selectedGisuId
        self._viewModel = .init(
            wrappedValue: .init(
                container: container,
                mode: mode,
                selectedGisuId: selectedGisuId,
                initialCategory: initialCategory,
                memberRoleRaw: UserDefaults.standard.string(forKey: AppStorageKey.memberRole)
            )
        )
    }

    // MARK: - Body

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                editorMainContent
                    .frame(minHeight: editorMinHeight)
            }
            .noticeEditorBindings(
                viewModel: viewModel,
                selectedHighlightColor: $selectedHighlightColor,
                newlyAddedLinkID: $newlyAddedLinkID,
                organizationType: organizationType,
                memberRoleRaw: memberRoleRaw,
                gisuId: gisuId,
                chapterId: chapterId,
                selectedGisuId: selectedGisuId,
                errorHandler: errorHandler,
                scrollProxy: proxy,
                dismiss: dismiss
            )
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newValue in
            scrollViewHeight = newValue
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.restoreDailyTokenUsage()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(navigationTitle)
        .navigationSubtitle(navigationSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaBar(edge: .top, content: topSafeAreaContent)
        .safeAreaBar(edge: .bottom, alignment: .leading, content: bottomSafeAreaContent)
        .noticeEditorPresentations(viewModel: viewModel)
    }

    // MARK: - Content

    /// 본문 콘텐츠 영역
    private var editorMainContent: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            NoticeEditorTextFieldSection(
                viewModel: viewModel,
                isTitleFieldFocused: $isTitleFieldFocused,
                onTitleSubmit: moveFocusToContentField
            )

            if !viewModel.noticeImages.isEmpty {
                NoticeEditorImageSection(
                    images: viewModel.noticeImages,
                    onRemove: viewModel.removeImage
                )
                .id(NoticeEditorScrollAnchor.imageSection)
            }

            if !viewModel.noticeLinks.isEmpty {
                NoticeEditorLinkSection(
                    links: $viewModel.noticeLinks,
                    newlyAddedLinkID: newlyAddedLinkID,
                    onRemove: viewModel.removeLink
                )
            }

            if viewModel.isVoteConfirmed {
                NoticeEditorVoteSection(
                    formData: $viewModel.voteFormData,
                    isEditMode: viewModel.isEditMode,
                    onDelete: viewModel.deleteVote,
                    onEdit: viewModel.editVote
                )
                .id(NoticeEditorScrollAnchor.voteSection)
            }
        }
    }

    // MARK: - Top Safe Area

    /// 상단 안전 영역: 공지 대상 선택 칩
    @ViewBuilder
    private func topSafeAreaContent() -> some View {
        if viewModel.selectedCategory.hasSubCategories
            && !viewModel.isEditMode
            && !viewModel.visibleSubCategories.isEmpty {
            NoticeEditorSubCategorySection(
                subCategories: viewModel.visibleSubCategories,
                showsExclusivityHint: viewModel.shouldShowTargetExclusivityHint,
                isHighlighted: viewModel.isSubCategoryHighlighted,
                onTap: handleSubCategoryTap
            )
        }
    }

    // MARK: - Bottom Safe Area

    /// 하단 안전 영역: 첨부·서식 도구 툴바 (제목 또는 내용에 포커스 시에만 표시)
    @ViewBuilder
    private func bottomSafeAreaContent() -> some View {
        if isTitleFieldFocused || viewModel.editorToolbarViewModel.isEditorActive {
            HStack {
                NoticeEditorAttachmentToolbar(
                    editorToolbarViewModel: viewModel.editorToolbarViewModel,
                    isEditMode: viewModel.isEditMode,
                    isAIButtonDisabled: viewModel.isAIProcessing
                        || viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isAISummaryButtonDisabled: viewModel.isAISummaryProcessing
                        || viewModel.isAIProcessing,
                    isPhotoPickerPresented: $isPhotoPickerPresented,
                    selectedPhotoItems: $viewModel.selectedPhotoItems,
                    selectedHighlightColor: $selectedHighlightColor,
                    onAddLink: addLinkAttachment,
                    onTapAI: handleTapAI,
                    onTapAISummary: handleTapAISummary,
                    onShowVotingSheet: viewModel.showVotingFormSheet
                )
                Spacer()
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultSpacing.spacing16)
        }
    }

    // MARK: - Toolbar

    /// 공지 생성/수정 화면 상단 툴바
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !viewModel.isEditMode {
            ToolBarCollection.ToolBarCenterMenu(
                items: viewModel.availableCategories,
                selection: categoryBinding,
                itemLabel: menuItemLabel,
                itemIcon: { $0.labelIcon }
            )
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.allowAlert.toggle()
                } label: {
                    Image(systemName: viewModel.allowAlert ? "bell.fill" : "bell.slash.fill")
                }
                .tint(viewModel.allowAlert ? .indigo500 : .secondary)
            }
            ToolBarCollection.AddBtn(
                action: saveNotice,
                disable: !viewModel.canSubmit,
                isLoading: viewModel.createState.isLoading,
                dismissOnTap: false
            )
        } else {
            ToolBarCollection.ConfirmBtn(
                action: saveNotice,
                disable: !viewModel.canSubmit,
                isLoading: viewModel.createState.isLoading,
                dismissOnTap: false
            )
        }
    }

    // MARK: - Navigation

    /// 화면 타이틀
    private var navigationTitle: String {
        if viewModel.isEditMode {
            return "공지 수정"
        }

        return menuItemLabel(viewModel.selectedCategory)
    }

    /// 메인 카테고리 서브타이틀
    private var navigationSubtitle: String {
        if viewModel.isEditMode {
            switch viewModel.selectedCategory {
            case .branch:
                return normalizedName(from: chapterName, fallback: "지부")
            case .school:
                return normalizedName(from: schoolName, fallback: "학교")
            case .all, .central, .part:
                return ""
            case .management(let scenario):
                return managementSubtitle(for: scenario)
            }
        }

        switch viewModel.selectedCategory {
        case .all, .central, .school, .branch, .part:
            return ""
        case .management(let scenario):
            return managementSubtitle(for: scenario)
        }
    }

    /// 운영진 시나리오별 서브타이틀 — 자동 바인딩되는 대상 정보를 사용자에게 명시
    private func managementSubtitle(for scenario: ManagementNoticeCategory) -> String {
        switch scenario {
        case .centralAll:
            return "중앙운영진 전체"
        case .schoolCore:
            let role = ManagementTeam(rawValue: memberRoleRaw)
            if role?.bindsOwnSchoolForSchoolCoreNotice == true {
                return normalizedName(from: schoolName, fallback: "본인 학교 회장단")
            }
            return "전체 학교 회장단"
        case .schoolPartLeader:
            let role = ManagementTeam(rawValue: memberRoleRaw)
            if role?.bindsOwnSchoolForPartLeaderNotice == true {
                return normalizedName(from: schoolName, fallback: "본인 학교 파트장")
            }
            return "전체 학교 파트장"
        }
    }

    /// 메인 카테고리 선택 바인딩
    private var categoryBinding: Binding<EditorMainCategory> {
        Binding(
            get: { viewModel.selectedCategory },
            set: { viewModel.selectCategory($0) }
        )
    }

    /// 상단 메뉴 항목 라벨 (권한/선택 기수 반영)
    private func menuItemLabel(_ category: EditorMainCategory) -> String {
        switch category {
        case .central:
            return viewModel.selectedGenerationTitle ?? category.labelText
        default:
            return category.labelText
        }
    }

    // MARK: - Function

    /// 제목 필드 제출 시 내용 필드로 포커스를 이동합니다.
    private func moveFocusToContentField() {
        isTitleFieldFocused = false
        isContentFieldFocused = true
    }

    /// 링크 첨부를 추가하고 자동 포커스 대상을 갱신합니다.
    private func addLinkAttachment() {
        let newItem = NoticeLinkItem()
        viewModel.noticeLinks.append(newItem)
        newlyAddedLinkID = newItem.id
    }

    /// 공지 저장을 실행합니다.
    private func saveNotice() {
        Task {
            await viewModel.saveNotice()
        }
    }

    /// 서브카테고리 칩 탭 이벤트를 처리합니다.
    private func handleSubCategoryTap(_ subCategory: EditorSubCategory) {
        if subCategory.hasFilter {
            viewModel.selectSubCategoryIfNeeded(subCategory)
            viewModel.openSheet(for: subCategory)
            return
        }

        viewModel.toggleSubCategory(subCategory)
    }

    /// AI 도우미 버튼 탭 (본문 다듬기)
    private func handleTapAI() {
        viewModel.requestAIImprovement()
    }

    /// AI 요약 버튼 탭 (외부 텍스트 → 공지 초안)
    private func handleTapAISummary() {
        viewModel.openAISummaryInput()
    }

    // MARK: - Helper

    /// 앞뒤 공백/개행 제거 후 비어있으면 fallback을 반환합니다.
    private func normalizedName(from rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

// MARK: - Constants

private extension NoticeEditorView {
    enum Constants {
        /// 스크롤 뷰 높이가 아직 측정되지 않았을 때 본문에 보장할 최소 높이
        static let editorMinHeight: CGFloat = 400
    }
}
