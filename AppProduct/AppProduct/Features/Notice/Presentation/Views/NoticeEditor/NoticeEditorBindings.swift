//
//  NoticeEditorBindings.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI
import UIKit
import PhotosUI

// MARK: - ViewModifier

struct NoticeEditorBindings: ViewModifier {

    // MARK: - Property

    @Bindable var viewModel: NoticeEditorViewModel
    @Binding var selectedHighlightColor: HighlightColor
    @Binding var newlyAddedLinkID: UUID?

    let organizationType: String
    let memberRoleRaw: String
    let gisuId: Int
    let chapterId: Int
    let selectedGisuId: Int?
    let errorHandler: ErrorHandler
    let scrollProxy: ScrollViewProxy
    let dismiss: DismissAction

    // MARK: - Constants

    private enum Constants {
        static let imageSectionScrollID: String = "notice_editor_image_section"
        static let voteSectionScrollID: String = "notice_editor_vote_section"
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

    fileprivate func handleNoticeImagesCountChanged(oldValue: Int, newValue: Int) {
        guard newValue > oldValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy.scrollTo(Constants.imageSectionScrollID, anchor: .center)
        }
    }

    fileprivate func handleVoteConfirmStateChanged(oldValue: Bool, newValue: Bool) {
        guard !oldValue, newValue else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy.scrollTo(Constants.voteSectionScrollID, anchor: .center)
        }
    }

    fileprivate func handleCreateStateChanged(_ state: Loadable<NoticeDetail>) {
        switch state {
        case .loaded:
            dismiss()
        case .idle, .loading, .failed:
            break
        }
    }

    fileprivate func handleSelectedPhotoItemsChanged(_ newItems: [PhotosPickerItem]) {
        guard !newItems.isEmpty else { return }
        Task {
            await viewModel.loadSelectedPhotoItemsForNoticeUpload()
        }
    }

    fileprivate func handleUserContextChanged(gisuId: Int, chapterId: Int) {
        let editorGisuId = selectedGisuId ?? gisuId
        viewModel.updateUserContext(gisuId: editorGisuId, chapterId: chapterId)
    }

    fileprivate func handleHighlightColorChanged(_ newValue: HighlightColor) {
        Task { @MainActor in
            if let color = newValue.swiftUIColor {
                viewModel.editorToolbarViewModel.applyHighlight(color: color)
            } else {
                viewModel.editorToolbarViewModel.clearHighlight()
            }
        }
    }

    fileprivate func handleAIProcessingChanged(_ isProcessing: Bool) {
        if isProcessing {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: - Sub-Modifiers

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
    func noticeEditorBindings(
        viewModel: NoticeEditorViewModel,
        selectedHighlightColor: Binding<HighlightColor>,
        newlyAddedLinkID: Binding<UUID?>,
        organizationType: String,
        memberRoleRaw: String,
        gisuId: Int,
        chapterId: Int,
        selectedGisuId: Int?,
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
