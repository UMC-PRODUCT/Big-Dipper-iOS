//
//  TextSelectedToolbarView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import SwiftUI

/// 텍스트 선택 상태에서 노출되는 인라인 서식 툴바입니다.
struct TextSelectedToolbarView: View {

    @Bindable var viewModel: EditorToolbarViewModel
    var onInsertLink: () -> Void
    var onTapHighlight: () -> Void

    fileprivate enum Constants {
        static let toolbarHeight: CGFloat = 44
        static let horizontalSpacing: CGFloat = 8
        static let buttonCornerRadius: CGFloat = 10
        static let symbolSize: CGFloat = 18
        static let horizontalPadding: CGFloat = 8
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.horizontalSpacing) {
            formatButton(
                title: "B",
                isActive: viewModel.isBold,
                action: viewModel.toggleBold
            )

            formatButton(
                title: "I",
                isActive: viewModel.isItalic,
                action: viewModel.toggleItalic
            )

            formatButton(
                title: "U",
                isActive: viewModel.isUnderline,
                action: viewModel.toggleUnderline
            )

            formatButton(
                title: "S",
                isActive: viewModel.isStrikethrough,
                action: viewModel.toggleStrikethrough
            )

            imageButton(systemName: "highlighter", action: onTapHighlight)
            imageButton(systemName: "link", action: onInsertLink)
            imageButton(systemName: "textformat", action: viewModel.toggleFormatPanel)
        }
        .frame(height: Constants.toolbarHeight)
        .padding(.horizontal, Constants.horizontalPadding)
    }

    // MARK: - Components

    private func formatButton(
        title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(.body, weight: isActive ? .semibold : .regular, color: isActive ? .grey000 : .grey900)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: Constants.buttonCornerRadius)
                        .fill(isActive ? Color.indigo500 : Color.clear)
                }
                .contentShape(RoundedRectangle(cornerRadius: Constants.buttonCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func imageButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: Constants.symbolSize, weight: .medium))
                .foregroundStyle(Color.grey900)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
