//
//  NoticeEditorView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI
import PhotosUI
import SwiftData

struct NoticeEditorView: View {

    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorHandler.self) private var errorHandler

    @AppStorage(AppStorageKey.organizationType) private var organizationType: String = ""
    @AppStorage(AppStorageKey.chapterName) private var chapterName: String = ""
    @AppStorage(AppStorageKey.schoolName) private var schoolName: String = ""
    @AppStorage(AppStorageKey.gisuId) private var gisuId: Int = 0
    @AppStorage(AppStorageKey.chapterId) private var chapterId: Int = 0
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""

    @State private var viewModel: NoticeEditorViewModel
    private let selectedGisuId: Int?

    @State private var newlyAddedLinkID: UUID?
    @State private var isPhotoPickerPresented = false
    @State private var selectedHighlightColor: HighlightColor = .none

    @FocusState private var isTitleFieldFocused: Bool
    @FocusState private var isContentFieldFocused: Bool

    @State private var scrollViewHeight: CGFloat = 0

    private var editorMinHeight: CGFloat {
        max(scrollViewHeight, 400)
    }

    // MARK: - Initializer

    init(
        container: DIContainer,
        mode: NoticeEditorMode = .create,
        selectedGisuId: Int? = nil,
        initialCategory: EditorMainCategory? = nil
    ) {
        self.selectedGisuId = selectedGisuId
        self._viewModel = .init(
            wrappedValue: .init(
                container: container,
                mode: mode,
                selectedGisuId: selectedGisuId,
                initialCategory: initialCategory
            )
        )
    }

    // MARK: - Body

    var body: some View {
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
                .id(Constants.imageSectionScrollID)
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
                .id(Constants.voteSectionScrollID)
            }
        }
    }

    // MARK: - Top Safe Area

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

    @ViewBuilder
    private func bottomSafeAreaContent() -> some View {
        if isTitleFieldFocused || viewModel.editorToolbarViewModel.isEditorActive {
            HStack {
                NoticeEditorAttachmentToolbar(
                    editorToolbarViewModel: viewModel.editorToolbarViewModel,
                    isEditMode: viewModel.isEditMode,
                    isAIButtonDisabled: viewModel.isAIProcessing
                        || viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isPhotoPickerPresented: $isPhotoPickerPresented,
                    selectedPhotoItems: $viewModel.selectedPhotoItems,
                    selectedHighlightColor: $selectedHighlightColor,
                    onAddLink: addLinkAttachment,
                    onTapAI: handleTapAI,
                    onShowVotingSheet: viewModel.showVotingFormSheet
                )
                Spacer()
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultSpacing.spacing16)
        }
    }

    // MARK: - Toolbar

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

    private var navigationTitle: String {
        if viewModel.isEditMode {
            return "공지 수정"
        }

        return menuItemLabel(viewModel.selectedCategory)
    }

    private var navigationSubtitle: String {
        if viewModel.isEditMode {
            switch viewModel.selectedCategory {
            case .branch:
                return normalizedName(from: chapterName, fallback: "지부")
            case .school:
                return normalizedName(from: schoolName, fallback: "학교")
            case .all, .central, .part:
                return ""
            }
        }

        switch viewModel.selectedCategory {
        case .all, .central, .school, .branch, .part:
            return ""
        }
    }

    private var categoryBinding: Binding<EditorMainCategory> {
        Binding(
            get: { viewModel.selectedCategory },
            set: { viewModel.selectCategory($0) }
        )
    }

    private func menuItemLabel(_ category: EditorMainCategory) -> String {
        switch category {
        case .central:
            return viewModel.selectedGenerationTitle ?? category.labelText
        default:
            return category.labelText
        }
    }

    // MARK: - Function

    private func moveFocusToContentField() {
        isTitleFieldFocused = false
        isContentFieldFocused = true
    }

    private func addLinkAttachment() {
        let newItem = NoticeLinkItem()
        viewModel.noticeLinks.append(newItem)
        newlyAddedLinkID = newItem.id
    }

    private func saveNotice() {
        Task {
            await viewModel.saveNotice()
        }
    }

    private func handleSubCategoryTap(_ subCategory: EditorSubCategory) {
        if subCategory.hasFilter {
            viewModel.selectSubCategoryIfNeeded(subCategory)
            viewModel.openSheet(for: subCategory)
            return
        }

        viewModel.toggleSubCategory(subCategory)
    }

    private func handleTapAI() {
        viewModel.requestAIImprovement()
    }

    private func normalizedName(from rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

// MARK: - Constants

private extension NoticeEditorView {
    enum Constants {
        static let imageSectionScrollID: String = "notice_editor_image_section"
        static let voteSectionScrollID: String = "notice_editor_vote_section"
    }
}
