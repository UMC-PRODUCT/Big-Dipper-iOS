//
//  NoticeEditorTextFieldSection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

/// 공지 에디터의 제목 + 리치 텍스트 입력 섹션입니다.
struct NoticeEditorTextFieldSection: View {

    // MARK: - Property

    @Bindable var viewModel: NoticeEditorViewModel
    @FocusState.Binding var isTitleFieldFocused: Bool
    let onTitleSubmit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ArticleTextField(
                placeholder: .title,
                text: $viewModel.title,
                focused: $isTitleFieldFocused,
                submitLabel: .next,
                onSubmit: onTitleSubmit
            )

            Divider()

            NoticeRichTextView(
                toolbarViewModel: viewModel.editorToolbarViewModel,
                attributedText: $viewModel.richAttributedContent,
                placeholder: "내용을 입력해주세요."
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .onChange(of: viewModel.richAttributedContent) { _, newValue in
                viewModel.content = MarkdownSerializer.serialize(newValue)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.top, DefaultSpacing.spacing24)
        .padding(.bottom, DefaultSpacing.spacing32)
    }
}
