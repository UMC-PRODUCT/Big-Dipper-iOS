//
//  NoticeEditorBindings.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import UIKit
import PhotosUI
import UMCFoundation
import NoticeDomain

// MARK: - ViewModifier

/// 공지 에디터 화면의 onChange / task 등 상태 동기화 계열 modifier를 묶은 ViewModifier입니다.
struct NoticeEditorBindings: ViewModifier {

    // MARK: - Property

    @Bindable var viewModel: NoticeEditorViewModel
    @Binding var selectedHighlightColor: HighlightColor
    @Binding var newlyAddedLinkID: UUID?

    let organizationType: String
    let memberRoleRaw: String
    let gisuId: String
    let chapterId: String
    let selectedGisuId: String?
    let errorHandler: ErrorHandler
    let scrollProxy: ScrollViewProxy
    let dismiss: DismissAction

    // MARK: - Constants

    private enum Constants {
        /// 이미지/투표 섹션 스크롤 앵커 ID
        static let imageSectionScrollID: String = "notice_editor_image_section"
        static let voteSectionScrollID: String = "notice_editor_vote_section"
        /// 링크 추가 후 스크롤/포커스 안정화 대기 시간
        static let linkScrollDelayNanos: UInt64 = 120_000_000
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .task {
                viewModel.updateErrorHandler(errorHandler)
                applyInitialOrganizationType()
                applyInitialMemberRole()
                applyInitialUserContext()
            }
            .modifier(ScrollAnchorChanges(owner: self))
            .modifier(SaveAndMediaChanges(owner: self))
            .modifier(AppStorageChanges(owner: self))
            .modifier(ToolbarChanges(owner: self))
    }

    // MARK: - Initial Apply

    fileprivate func applyInitialOrganizationType() {
        viewModel.applyOrganizationType(organizationType)
    }

    fileprivate func applyInitialMemberRole() {
        viewModel.applyMemberRole(memberRoleRaw)
    }

    fileprivate func applyInitialUserContext() {
        let editorGisuId = selectedGisuId ?? gisuId
        viewModel.updateUserContext(gisuId: editorGisuId, chapterId: chapterId)
    }

    // MARK: - Handlers

    /// 링크 아이템이 추가되면 신규 카드로 스크롤하고 포커스 안정화를 대기합니다.
    fileprivate func handleNoticeLinksCountChanged(oldValue: Int, newValue: Int) {
        guard newValue > oldValue, let targetID = newlyAddedLinkID else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy.scrollTo(targetID, anchor: .center)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.linkScrollDelayNanos)
            newlyAddedLinkID = nil
        }
    }

    /// 이미지 아이템이 추가되면 이미지 섹션으로 자동 스크롤합니다.
    fileprivate func handleNoticeImagesCountChanged(oldValue: Int, newValue: Int) {
        guard newValue > oldValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy.scrollTo(Constants.imageSectionScrollID, anchor: .center)
        }
    }

    /// 투표가 생성되면 투표 섹션으로 자동 스크롤합니다.
    fileprivate func handleVoteConfirmStateChanged(oldValue: Bool, newValue: Bool) {
        guard !oldValue, newValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy.scrollTo(Constants.voteSectionScrollID, anchor: .center)
        }
    }

    /// 저장 상태 변화에 따라 화면 동작을 제어합니다.
    fileprivate func handleCreateStateChanged(_ state: Loadable<NoticeDetail>) {
        switch state {
        case .loaded:
            dismiss()
        case .idle, .loading, .failed:
            break
        }
    }

    /// 선택된 사진 아이템 변경 시 이미지를 로드합니다.
    fileprivate func handleSelectedPhotoItemsChanged(_ newItems: [PhotosPickerItem]) {
        guard !newItems.isEmpty else { return }
        Task {
            await viewModel.loadSelectedPhotoItemsForNoticeUpload()
        }
    }

    /// AppStorage 사용자 컨텍스트 변경을 ViewModel에 반영합니다.
    fileprivate func handleUserContextChanged(gisuId: String, chapterId: String) {
        let editorGisuId = selectedGisuId ?? gisuId
        viewModel.updateUserContext(gisuId: editorGisuId, chapterId: chapterId)
    }

    /// 형광펜 색상 선택 변경을 에디터 툴바에 반영합니다.
    fileprivate func handleHighlightColorChanged(_ newValue: HighlightColor) {
        Task { @MainActor in
            if let color = newValue.swiftUIColor {
                viewModel.editorToolbarViewModel.applyHighlight(color: color)
            } else {
                viewModel.editorToolbarViewModel.clearHighlight()
            }
        }
    }

    /// AI 처리 상태 변경 시 키보드 리사인을 처리합니다.
    fileprivate func handleAIProcessingChanged(_ isProcessing: Bool) {
        if isProcessing {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: - Sub-Modifiers (body 타입체크 부담 분산)

/// 스크롤 앵커 관련 변경 (링크 추가, 이미지 추가, 투표 확정) onChange 묶음
private struct ScrollAnchorChanges: ViewModifier {
    let owner: NoticeEditorBindings

    func body(content: Content) -> some View {
        content
            .onChange(of: owner.viewModel.noticeLinks.count) { oldValue, newValue in
                owner.handleNoticeLinksCountChanged(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: owner.viewModel.noticeImages.count) { oldValue, newValue in
                owner.handleNoticeImagesCountChanged(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: owner.viewModel.isVoteConfirmed) { oldValue, newValue in
                owner.handleVoteConfirmStateChanged(oldValue: oldValue, newValue: newValue)
            }
    }
}

/// 저장 상태 및 미디어(사진 피커) 변경 onChange 묶음
private struct SaveAndMediaChanges: ViewModifier {
    let owner: NoticeEditorBindings

    func body(content: Content) -> some View {
        content
            .onChange(of: owner.viewModel.createState) { _, newValue in
                owner.handleCreateStateChanged(newValue)
            }
            .onChange(of: owner.viewModel.selectedPhotoItems) { _, newItems in
                owner.handleSelectedPhotoItemsChanged(newItems)
            }
    }
}

/// AppStorage 기반 사용자 컨텍스트 변경 onChange 묶음
private struct AppStorageChanges: ViewModifier {
    let owner: NoticeEditorBindings

    func body(content: Content) -> some View {
        content
            .onChange(of: owner.organizationType) { _, newValue in
                owner.viewModel.applyOrganizationType(newValue)
            }
            .onChange(of: owner.memberRoleRaw) { _, newValue in
                owner.viewModel.applyMemberRole(newValue)
            }
            .onChange(of: owner.gisuId) { _, newValue in
                owner.handleUserContextChanged(gisuId: newValue, chapterId: owner.chapterId)
            }
            .onChange(of: owner.chapterId) { _, newValue in
                owner.handleUserContextChanged(gisuId: owner.gisuId, chapterId: newValue)
            }
    }
}

/// 툴바(형광펜, AI 처리) 관련 변경 onChange 묶음
private struct ToolbarChanges: ViewModifier {
    let owner: NoticeEditorBindings

    func body(content: Content) -> some View {
        content
            .onChange(of: owner.selectedHighlightColor) { _, newValue in
                owner.handleHighlightColorChanged(newValue)
            }
            .onChange(of: owner.viewModel.isAIProcessing) { _, isProcessing in
                owner.handleAIProcessingChanged(isProcessing)
            }
    }
}

// MARK: - View Extension

extension View {
    /// 공지 에디터의 상태 동기화 계열 modifier를 일괄 적용합니다.
    func noticeEditorBindings(
        viewModel: NoticeEditorViewModel,
        selectedHighlightColor: Binding<HighlightColor>,
        newlyAddedLinkID: Binding<UUID?>,
        organizationType: String,
        memberRoleRaw: String,
        gisuId: String,
        chapterId: String,
        selectedGisuId: String?,
        errorHandler: ErrorHandler,
        scrollProxy: ScrollViewProxy,
        dismiss: DismissAction
    ) -> some View {
        modifier(
            NoticeEditorBindings(
                viewModel: viewModel,
                selectedHighlightColor: selectedHighlightColor,
                newlyAddedLinkID: newlyAddedLinkID,
                organizationType: organizationType,
                memberRoleRaw: memberRoleRaw,
                gisuId: gisuId,
                chapterId: chapterId,
                selectedGisuId: selectedGisuId,
                errorHandler: errorHandler,
                scrollProxy: scrollProxy,
                dismiss: dismiss
            )
        )
    }
}
