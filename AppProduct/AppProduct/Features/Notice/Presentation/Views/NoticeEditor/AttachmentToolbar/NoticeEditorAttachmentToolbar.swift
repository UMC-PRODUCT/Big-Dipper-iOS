//
//  NoticeEditorAttachmentToolbar.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI
import PhotosUI

/// 공지 에디터 하단에 노출되는 첨부/서식 통합 스크롤 툴바입니다.
struct NoticeEditorAttachmentToolbar: View {

    // MARK: - Property

    @Bindable var editorToolbarViewModel: EditorToolbarViewModel
    let isEditMode: Bool
    let isAIButtonDisabled: Bool
    let isAISummaryButtonDisabled: Bool
    @Binding var isPhotoPickerPresented: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var selectedHighlightColor: HighlightColor
    let onAddLink: () -> Void
    let onTapAI: () -> Void
    let onTapAISummary: () -> Void
    let onShowVotingSheet: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let height: CGFloat = 44
        static let itemSpacing: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        GlassEffectContainer {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    scrollableItems
                }
            }
            .frame(height: Constants.height)
        }
        .glassEffect()
    }

    // MARK: - Components

    private var scrollableItems: some View {
        HStack(spacing: Constants.itemSpacing) {
            ToolbarIconButton(
                icon: "textformat.size",
                tint: editorToolbarViewModel.isFormatPanelVisible ? .indigo500 : .black
            ) {
                editorToolbarViewModel.toggleFormatPanel()
            }

            AttachmentMenuButton(
                isEditMode: isEditMode,
                isPhotoPickerPresented: $isPhotoPickerPresented,
                selectedPhotoItems: $selectedPhotoItems,
                onShowVotingSheet: onShowVotingSheet
            )

            ToolbarIconButton(icon: "link", action: onAddLink)
            ToolbarIconButton(icon: "sparkles", action: onTapAI)
                .disabled(isAIButtonDisabled)
                .opacity(isAIButtonDisabled ? 0.4 : 1)

            ToolbarIconButton(icon: "wand.and.stars", action: onTapAISummary)
                .disabled(isAISummaryButtonDisabled)
                .opacity(isAISummaryButtonDisabled ? 0.4 : 1)

            ToolbarTextFormatButton(
                title: "B",
                weight: .bold,
                isActive: editorToolbarViewModel.isBold
            ) {
                editorToolbarViewModel.toggleBold()
            }

            ToolbarTextFormatButton(
                title: "I",
                isItalic: true,
                isActive: editorToolbarViewModel.isItalic
            ) {
                editorToolbarViewModel.toggleItalic()
            }

            ToolbarTextFormatButton(
                title: "U",
                isUnderline: true,
                isActive: editorToolbarViewModel.isUnderline
            ) {
                editorToolbarViewModel.toggleUnderline()
            }

            ToolbarTextFormatButton(
                title: "S",
                isStrikethrough: true,
                isActive: editorToolbarViewModel.isStrikethrough
            ) {
                editorToolbarViewModel.toggleStrikethrough()
            }

            HighlightMenuButton(selectedHighlightColor: $selectedHighlightColor)
            ListMenuButton(editorToolbarViewModel: editorToolbarViewModel)

            ToolbarIconButton(
                icon: "text.quote",
                tint: editorToolbarViewModel.isBlockquote ? .indigo500 : .black
            ) {
                editorToolbarViewModel.toggleBlockquote()
            }
        }
    }
}
