//
//  NoticeEditorView.swift
//  AppProduct
//
//  Created by 이예지 on 1/24/26.
//

import SwiftUI
import PhotosUI

/// 공지사항 작성/수정 에디터 화면
///
/// 카테고리 선택, 제목/본문 입력, 이미지/링크/투표 첨부를 지원합니다.
struct NoticeEditorView: View {

    // MARK: - Property
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorHandler.self) private var errorHandler

    /// 사용자 조직 타입 (중앙/지부/학교)
    @AppStorage(AppStorageKey.organizationType) private var organizationType: String = ""

    /// 사용자 지부명
    @AppStorage(AppStorageKey.chapterName) private var chapterName: String = ""

    /// 사용자 학교명
    @AppStorage(AppStorageKey.schoolName) private var schoolName: String = ""

    /// 사용자 기수 ID
    @AppStorage(AppStorageKey.gisuId) private var gisuId: Int = 0

    /// 사용자 지부 ID
    @AppStorage(AppStorageKey.chapterId) private var chapterId: Int = 0
    /// 사용자 역할
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""

    @State private var viewModel: NoticeEditorViewModel
    private let selectedGisuId: Int?

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

    // MARK: - Constants

    private enum Constants {
        static let chipSpacing: CGFloat = 8
        static let toolButtonIconSize: CGFloat = 20
        static let toolButtonFrame: CGSize = .init(width: 30, height: 30)

        static let alarmPadding: EdgeInsets = .init(top: 9, leading: .zero, bottom: 9, trailing: .zero)
        static let alarmWidth: CGFloat = 110

        static let targetSheetLargeDetentFraction: CGFloat = 0.86
        static let targetSheetSmallDetentFraction: CGFloat = 0.38

        /// 하단 액세서리와 본문이 겹치지 않도록 확보하는 여백
        static let contentBottomInset: CGFloat = 0
        static let editorToolbarHeight: CGFloat = 44
        static let toolbarItemSpacing: CGFloat = 12

        /// 링크 카드와 하단 액세서리 사이 추가 간격
        static let linkSectionBottomPadding: CGFloat = DefaultSpacing.spacing8

        /// 링크 추가 후 스크롤/포커스 안정화 대기 시간
        static let linkScrollDelayNanos: UInt64 = 120_000_000

        /// 이미지/투표 섹션 스크롤 앵커 ID
        static let imageSectionScrollID: String = "notice_editor_image_section"
        static let voteSectionScrollID: String = "notice_editor_vote_section"
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                editorMainContent
                    .frame(minHeight: editorMinHeight)
            }
            .onChange(of: viewModel.noticeLinks.count) { oldValue, newValue in
                handleNoticeLinksCountChanged(oldValue: oldValue, newValue: newValue, proxy: proxy)
            }
            .onChange(of: viewModel.noticeImages.count) { oldValue, newValue in
                handleNoticeImagesCountChanged(oldValue: oldValue, newValue: newValue, proxy: proxy)
            }
            .onChange(of: viewModel.isVoteConfirmed) { oldValue, newValue in
                handleVoteConfirmStateChanged(oldValue: oldValue, newValue: newValue, proxy: proxy)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newValue in
            scrollViewHeight = newValue
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(navigationTitle)
        .navigationSubtitle(navigationSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            viewModel.updateErrorHandler(errorHandler)
            applyInitialOrganizationType()
            applyInitialMemberRole()
            applyInitialUserContext()
        }
        .onChange(of: viewModel.createState) { _, newValue in
            handleCreateStateChanged(newValue)
        }
        .safeAreaBar(edge: .top, content: topSafeAreaContent)
        .sheet(item: $viewModel.activeSheetType, content: targetSheet)
        .safeAreaBar(edge: .bottom, alignment: .leading, content: bottomSafeAreaContent)
        .onChange(of: viewModel.selectedPhotoItems) { _, newItems in
            handleSelectedPhotoItemsChanged(newItems)
        }
        .onChange(of: organizationType) { _, newValue in
            handleOrganizationTypeChanged(newValue)
        }
        .onChange(of: memberRoleRaw) { _, newValue in
            handleMemberRoleChanged(newValue)
        }
        .onChange(of: gisuId) { _, newValue in
            handleUserContextChanged(gisuId: newValue, chapterId: chapterId)
        }
        .onChange(of: chapterId) { _, newValue in
            handleUserContextChanged(gisuId: gisuId, chapterId: newValue)
        }
        .fullScreenCover(isPresented: $viewModel.showVoting, content: votingSheet)
        .alertPrompt(item: $viewModel.alertPrompt)
        .overlay {
            if viewModel.isAIProcessing {
                AILoadingOverlay(streamingText: viewModel.aiStreamingText)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .center)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isAIProcessing)
        .onChange(of: viewModel.isAIProcessing) { _, isProcessing in
            if isProcessing {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
        .onChange(of: selectedHighlightColor) { _, newValue in
            print("[Highlight] 선택 변경 → \(newValue.name)")
            Task { @MainActor in
                if let color = newValue.swiftUIColor {
                    print("[Highlight] applyHighlight 호출 → \(newValue.name)")
                    viewModel.editorToolbarViewModel.applyHighlight(color: color)
                } else {
                    print("[Highlight] clearHighlight 호출")
                    viewModel.editorToolbarViewModel.clearHighlight()
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.editorToolbarViewModel.isFormatPanelVisible },
                set: { if !$0 { viewModel.editorToolbarViewModel.dismissFormatPanel() } }
            )
        ) {
            FormatPanelView(viewModel: viewModel.editorToolbarViewModel)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
    }

    // MARK: - Content

    /// 본문 콘텐츠 영역
    private var editorMainContent: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            textfieldSection

            if !viewModel.noticeImages.isEmpty {
                imageSection
                    .id(Constants.imageSectionScrollID)
            }

            if !viewModel.noticeLinks.isEmpty {
                linkSection
            }

            if viewModel.isVoteConfirmed {
                voteSection
                    .id(Constants.voteSectionScrollID)
            }
        }
        .padding(.bottom, Constants.contentBottomInset)
    }

    // MARK: - Top Safe Area

    /// 상단 안전 영역: 공지 대상 선택 칩
    @ViewBuilder
    private func topSafeAreaContent() -> some View {
        if viewModel.selectedCategory.hasSubCategories
            && !viewModel.isEditMode
            && !viewModel.visibleSubCategories.isEmpty {
            subCategorySection
        }
    }

    /// 공지 대상 선택 칩 섹션
    private var subCategorySection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            HStack(alignment: .center) {
                Text("공지 대상 선택")
                    .appFont(.calloutEmphasis)

                if viewModel.shouldShowTargetExclusivityHint {
                    Text("지부와 학교는 동시에 선택할 수 없습니다.")
                        .appFont(.footnote, color: .grey400)
                }
            }

            HStack(spacing: Constants.chipSpacing) {
                ForEach(viewModel.visibleSubCategories) { subCategory in
                    ChipButton(
                        subCategory.labelText,
                        isSelected: viewModel.isSubCategoryHighlighted(subCategory),
                        trailingIcon: subCategory.hasFilter ? true : nil
                    ) {
                        handleSubCategoryTap(subCategory)
                    }
                    .buttonSize(.medium)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Bottom Safe Area

    /// 하단 안전 영역: 첨부·서식 도구 툴바 (제목 또는 내용에 포커스 시에만 표시)
    @ViewBuilder
    private func bottomSafeAreaContent() -> some View {
        if isTitleFieldFocused || viewModel.editorToolbarViewModel.isEditorActive {
            HStack {
                attachmentToolbar
                Spacer()
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultSpacing.spacing16)
        }
    }

    /// 첨부·서식 도구 통합 스크롤 툴바
    private var attachmentToolbar: some View {
        GlassEffectContainer {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    scrollableToolbarItems
                }
            }
            .frame(height: Constants.editorToolbarHeight)
        }
        .glassEffect()
    }

    private var scrollableToolbarItems: some View {
        let toolVM = viewModel.editorToolbarViewModel
        return HStack(spacing: Constants.toolbarItemSpacing) {
            // 서식 도구
            toolButton(
                icon: "textformat.size",
                tint: toolVM.isFormatPanelVisible ? .indigo500 : .black
            ) {
                toolVM.toggleFormatPanel()
            }
            // 첨부 도구
            attachmentMenuButton
            toolButton(icon: "link", action: addLinkAttachment)
            // 기타 도구
            toolButton(icon: "sparkles", action: handleTapAI)
            // 인라인 서식
            textFormatButton("B", weight: .bold, isActive: toolVM.isBold) { toolVM.toggleBold() }
            textFormatButton("I", isItalic: true, isActive: toolVM.isItalic) { toolVM.toggleItalic() }
            textFormatButton("U", isUnderline: true, isActive: toolVM.isUnderline) { toolVM.toggleUnderline() }
            textFormatButton("S", isStrikethrough: true, isActive: toolVM.isStrikethrough) { toolVM.toggleStrikethrough() }
            highlightMenuButton
            listMenuButton
        }
    }

    /// 목록 스타일 선택 메뉴
    private var listMenuButton: some View {
        Menu {
            Button {
                viewModel.editorToolbarViewModel.applyList(.bullet)
            } label: {
                Label("구분점", systemImage: "list.bullet")
            }
            Button {
                viewModel.editorToolbarViewModel.applyList(.dash)
            } label: {
                Label("대시선", systemImage: "list.dash")
            }
            Button {
                viewModel.editorToolbarViewModel.applyList(.number)
            } label: {
                Label("숫자", systemImage: "list.number")
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: Constants.toolButtonIconSize))
                .foregroundStyle(.black)
                .frame(width: Constants.toolButtonFrame.width, height: Constants.toolButtonFrame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }

    /// 클립 버튼 → 사진/투표 첨부 메뉴
    private var attachmentMenuButton: some View {
        Menu {
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("사진", systemImage: "photo.fill")
            }

            if !viewModel.isEditMode {
                Button {
                    viewModel.showVotingFormSheet()
                } label: {
                    Label("투표", systemImage: "checklist")
                }
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: Constants.toolButtonIconSize))
                .foregroundStyle(.black)
                .frame(width: Constants.toolButtonFrame.width, height: Constants.toolButtonFrame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $viewModel.selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
    }

    /// 형광펜 색상 메뉴 버튼
    private var highlightMenuButton: some View {
        Menu {
            Section {
                Button {
                    selectedHighlightColor = .none
                } label: {
                    Label("없음", systemImage: selectedHighlightColor == .none ? "checkmark" : "xmark")
                }
            }

            Section {
                ForEach(HighlightColor.colorCases, id: \.self) { option in
                    Button {
                        selectedHighlightColor = option
                    } label: {
                        Label {
                            Text(option.name)
                        } icon: {
                            Image(uiImage: option.circleImage)
                        }
                        if selectedHighlightColor == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: Constants.toolButtonIconSize))
               .foregroundStyle(selectedHighlightColor.displayColor)
                .frame(width: Constants.toolButtonFrame.width, height: Constants.toolButtonFrame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }

    /// 툴바 아이콘 버튼 공통 구성
    private func toolButton(icon: String, tint: Color = .black, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Constants.toolButtonIconSize))
                .foregroundStyle(tint)
                .frame(width: Constants.toolButtonFrame.width, height: Constants.toolButtonFrame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }

    /// 서식 텍스트 버튼 (B/I/U/S) — 실제 서식 미리보기 적용
    private func textFormatButton(
        _ title: String,
        weight: Font.Weight = .regular,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Constants.toolButtonIconSize, weight: weight).italic(isItalic))
                .underline(isUnderline)
                .strikethrough(isStrikethrough)
                .foregroundStyle(isActive ? Color.indigo500 : .black)
                .frame(width: Constants.toolButtonFrame.width, height: Constants.toolButtonFrame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }

    // MARK: - Sections

    /// 제목/내용 입력 섹션
    private var textfieldSection: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ArticleTextField(
                placeholder: .title,
                text: $viewModel.title,
                focused: $isTitleFieldFocused,
                submitLabel: .next,
                onSubmit: moveFocusToContentField
            )

            Divider()

            // 리치 텍스트 에디터 (NSAttributedString 기반)
            NoticeRichTextView(
                toolbarViewModel: viewModel.editorToolbarViewModel,
                attributedText: $viewModel.richAttributedContent,
                placeholder: "내용을 입력해주세요."
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .onChange(of: viewModel.richAttributedContent) { _, newValue in
                // 서버 전송용 Markdown String으로 동기화
                viewModel.content = MarkdownSerializer.serialize(newValue)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.top, DefaultSpacing.spacing24)
        .padding(.bottom, DefaultSpacing.spacing32)
    }

    /// 이미지 첨부 섹션
    private var imageSection: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(viewModel.noticeImages, id: \.id) { item in
                    ImageAttachmentCard(
                        id: item.id,
                        imageData: item.imageData,
                        imageURL: item.imageURL,
                        isLoading: item.isLoading,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.removeImage(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .scrollIndicators(.hidden)
    }

    /// 링크 첨부 섹션
    private var linkSection: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ForEach($viewModel.noticeLinks, id: \.id) { $item in
                LinkAttachmentCard(
                    link: $item.link,
                    shouldAutoFocus: $item.wrappedValue.id == newlyAddedLinkID,
                    onDismiss: {
                        viewModel.removeLink($item.wrappedValue)
                    }
                )
                .id($item.wrappedValue.id)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, Constants.linkSectionBottomPadding)
    }

    /// 투표 첨부 섹션
    private var voteSection: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            voteAttachmentCard

            Label("글 게시 후 투표는 수정이 불가능해요.", systemImage: "exclamationmark.circle")
                .foregroundStyle(.grey500)
                .appFont(.footnote)
        }
    }

    /// 편집 모드에 맞는 투표 카드
    private var voteAttachmentCard: some View {
        Group {
            if viewModel.isEditMode {
                VoteAttachmentCard(
                    formData: $viewModel.voteFormData,
                    mode: .readonly,
                    onDelete: viewModel.deleteVote
                )
            } else {
                VoteAttachmentCard(
                    formData: $viewModel.voteFormData,
                    mode: .editable,
                    onDelete: viewModel.deleteVote,
                    onEdit: viewModel.editVote
                )
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    /// 알림 발송 토글
    private var alarmToggle: some View {
        Toggle(isOn: $viewModel.allowAlert) {
            Label(
                viewModel.allowAlert ? "알림 발송" : "알림 미발송",
                systemImage: viewModel.allowAlert ? "bell.fill" : "bell.slash.fill"
            )
            .frame(width: Constants.alarmWidth)
            .padding(Constants.alarmPadding)
        }
        .appFont(.body, weight: .medium)
        .toggleStyle(.button)
        .tint(.indigo500)
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
            }
        }

        switch viewModel.selectedCategory {
        case .all, .central, .school, .branch, .part:
            return ""
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

    /// 타겟 선택 시트 높이 설정
    private func targetSheetDetents(for sheetType: TargetSheetType) -> Set<PresentationDetent> {
        switch sheetType {
        case .part, .branch:
            return [.fraction(Constants.targetSheetSmallDetentFraction)]
        case .school:
            return [.fraction(Constants.targetSheetLargeDetentFraction)]
        }
    }

    // MARK: - View Builders

    /// 타겟 선택 시트를 표시합니다.
    private func targetSheet(_ sheetType: TargetSheetType) -> some View {
        TargetSheetView(viewModel: viewModel, sheetType: sheetType)
            .presentationDetents(targetSheetDetents(for: sheetType))
            .presentationDragIndicator(.visible)
    }

    /// 투표 폼 시트를 표시합니다.
    private func votingSheet() -> some View {
        VotingFormSheetView(
            formData: $viewModel.voteFormData,
            onCancel: viewModel.cancelVotingEdit,
            onConfirm: viewModel.confirmVote,
            mode: viewModel.isVoteConfirmed ? .edit : .create
        )
    }

    // MARK: - Function

    /// 초기 진입 시 조직 타입을 ViewModel에 반영합니다.
    private func applyInitialOrganizationType() {
        viewModel.applyOrganizationType(organizationType)
    }

    /// 초기 진입 시 멤버 역할을 ViewModel에 반영합니다.
    private func applyInitialMemberRole() {
        viewModel.applyMemberRole(memberRoleRaw)
    }

    /// 초기 진입 시 사용자 컨텍스트를 ViewModel에 반영합니다.
    private func applyInitialUserContext() {
        let editorGisuId = selectedGisuId ?? gisuId
        viewModel.updateUserContext(gisuId: editorGisuId, chapterId: chapterId)
    }

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

    /// 저장 상태 변화에 따라 화면 동작을 제어합니다.
    private func handleCreateStateChanged(_ state: Loadable<NoticeDetail>) {
        switch state {
        case .loaded:
            dismiss()
        case .idle, .loading, .failed:
            break
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

    /// 링크 아이템이 추가되면 신규 카드로 스크롤하고 포커스 안정화를 대기합니다.
    private func handleNoticeLinksCountChanged(
        oldValue: Int,
        newValue: Int,
        proxy: ScrollViewProxy
    ) {
        guard newValue > oldValue, let targetID = newlyAddedLinkID else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(targetID, anchor: .center)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.linkScrollDelayNanos)
            newlyAddedLinkID = nil
        }
    }

    /// 이미지 아이템이 추가되면 이미지 섹션으로 자동 스크롤합니다.
    private func handleNoticeImagesCountChanged(
        oldValue: Int,
        newValue: Int,
        proxy: ScrollViewProxy
    ) {
        guard newValue > oldValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Constants.imageSectionScrollID, anchor: .center)
        }
    }

    /// 투표가 생성되면 투표 섹션으로 자동 스크롤합니다.
    private func handleVoteConfirmStateChanged(
        oldValue: Bool,
        newValue: Bool,
        proxy: ScrollViewProxy
    ) {
        guard !oldValue, newValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Constants.voteSectionScrollID, anchor: .center)
        }
    }

    /// 선택된 사진 아이템 변경 시 이미지를 로드합니다.
    private func handleSelectedPhotoItemsChanged(_ newItems: [PhotosPickerItem]) {
        guard !newItems.isEmpty else { return }

        Task {
            await viewModel.loadSelectedPhotoItemsForNoticeUpload()
        }
    }

    /// AppStorage 조직 타입 변경을 ViewModel에 반영합니다.
    private func handleOrganizationTypeChanged(_ newValue: String) {
        viewModel.applyOrganizationType(newValue)
    }

    /// AppStorage 멤버 역할 변경을 ViewModel에 반영합니다.
    private func handleMemberRoleChanged(_ newValue: String) {
        viewModel.applyMemberRole(newValue)
    }

    /// AppStorage 사용자 컨텍스트 변경을 ViewModel에 반영합니다.
    private func handleUserContextChanged(gisuId: Int, chapterId: Int) {
        let editorGisuId = selectedGisuId ?? gisuId
        viewModel.updateUserContext(gisuId: editorGisuId, chapterId: chapterId)
    }

    // MARK: - Rich Editor Handlers

    /// 링크 삽입 버튼 탭: 기존 링크 첨부 로직 재사용
    private func handleInsertLink() {
        addLinkAttachment()
    }

    /// AI 도우미 버튼 탭
    private func handleTapAI() {
        Task {
            await viewModel.improveContentWithAI()
        }
    }

    // MARK: - Helper

    /// 앞뒤 공백/개행 제거 후 비어있으면 fallback을 반환합니다.
    private func normalizedName(from rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

}

// MARK: - HighlightColor

private enum HighlightColor: CaseIterable {
    case none, purple, pink, orange, mint, blue

    /// 팔레트에 표시할 색상 케이스 (없음 제외)
    static var colorCases: [HighlightColor] { [.purple, .pink, .orange, .mint, .blue] }

    var name: String {
        switch self {
        case .none:   return "없음"
        case .purple: return "보라색"
        case .pink:   return "분홍색"
        case .orange: return "주황색"
        case .mint:   return "민트색"
        case .blue:   return "파란색"
        }
    }

    /// 텍스트에 적용되는 반투명 배경 색상 (none이면 nil)
    var swiftUIColor: Color? {
        switch self {
        case .none:   return nil
        case .purple: return .purple.opacity(0.35)
        case .pink:   return .pink.opacity(0.35)
        case .orange: return .orange.opacity(0.35)
        case .mint:   return .mint.opacity(0.35)
        case .blue:   return .blue.opacity(0.35)
        }
    }

    /// 메뉴 아이콘에 표시되는 진한 색상
    var displayColor: Color {
        switch self {
        case .none:   return .black
        case .purple: return .purple
        case .pink:   return .pink
        case .orange: return .orange
        case .mint:   return .mint
        case .blue:   return .blue
        }
    }

    /// Menu 아이콘용 컬러 원형 UIImage (template 렌더링 무시)
    var circleImage: UIImage {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(displayColor).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - AILoadingOverlay

/// AI 글 개선 처리 중 표시되는 전체 화면 로딩 오버레이입니다.
private struct AILoadingOverlay: View {
    let streamingText: String

    private enum Constants {
        static let overlayOpacity: Double = 0.55
        static let cardCornerRadius: CGFloat = 20
        static let iconSize: CGFloat = 36
        static let cardPadding: EdgeInsets = .init(top: 24, leading: 28, bottom: 24, trailing: 28)
        static let cardMaxWidth: CGFloat = 300
        static let streamingLineLimit: Int = 3
    }

    var body: some View {
        ZStack {
            Color.black.opacity(Constants.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: DefaultSpacing.spacing16) {
                Image(systemName: "sparkles")
                    .font(.system(size: Constants.iconSize, weight: .medium))
                    .foregroundStyle(.indigo500)
                    .symbolEffect(.variableColor.iterative.reversing)

                Text("AI가 글을 개선하고 있어요...")
                    .appFont(.calloutEmphasis)
                    .multilineTextAlignment(.center)

                if !streamingText.isEmpty {
                    Text(streamingText)
                        .appFont(.footnote, color: .grey500)
                        .lineLimit(Constants.streamingLineLimit)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.15), value: streamingText)
                }
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: Constants.cardMaxWidth)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
        }
    }
}
