//
//  NoticeEditorAttachmentToolbar.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import PhotosUI
import CoreDesignSystem

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
        static let aiIconSize: CGFloat = 20
        static let aiIconFrame: CGSize = .init(width: 30, height: 30)
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

    private var isBothAIDisabled: Bool {
        isAIButtonDisabled && isAISummaryButtonDisabled
    }

    private var aiMenu: some View {
        Menu {
            Button {
                onTapAI()
            } label: {
                Label("본문 다듬기", systemImage: "sparkles")
            }
            .disabled(isAIButtonDisabled)

            Button {
                onTapAISummary()
            } label: {
                Label("붙여넣고 요약", systemImage: "wand.and.stars")
            }
            .disabled(isAISummaryButtonDisabled)
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: Constants.aiIconSize))
                .foregroundStyle(isBothAIDisabled ? Color.black.opacity(0.4) : Color.black)
                .frame(
                    width: Constants.aiIconFrame.width,
                    height: Constants.aiIconFrame.height
                )
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }

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
            aiMenu

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
