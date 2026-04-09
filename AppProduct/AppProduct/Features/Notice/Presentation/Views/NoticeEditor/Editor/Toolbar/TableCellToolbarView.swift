//
//  TableCellToolbarView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import SwiftUI

/// 표 셀 편집 전용 툴바입니다.
///
/// 들여쓰기, 내어쓰기, 인용구 토글과 목록 스타일 선택 액션을 제공합니다.
struct TableCellToolbarView: View {

    // MARK: - Property

    @Bindable var viewModel: EditorToolbarViewModel

    @State private var isListDialogPresented = false

    // MARK: - Constants

    private enum Constants {
        static let toolbarHeight: CGFloat = 44
        static let iconSize: CGFloat = 16
        static let horizontalPadding: CGFloat = 8
        static let labelSpacing: CGFloat = 6
        static let activeColor: Color = .indigo500
        static let inactiveColor: Color = .grey700
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: .zero) {
            outdentButton
            indentButton
            blockquoteButton
            listButton
        }
        .frame(height: Constants.toolbarHeight)
        .confirmationDialog(
            "목록 스타일 선택",
            isPresented: $isListDialogPresented,
            titleVisibility: .visible
        ) {
            Button("구분점") {
                viewModel.applyList(.bullet)
            }

            Button("대시선") {
                viewModel.applyList(.dash)
            }

            Button("숫자") {
                viewModel.applyList(.number)
            }

            Button("취소", role: .cancel) { }
        }
    }

    // MARK: - Components

    private var outdentButton: some View {
        Button {
            viewModel.applyOutdent()
        } label: {
            toolbarLabel(
                title: "Outdent",
                systemImage: "decrease.indent"
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    private var indentButton: some View {
        Button {
            viewModel.applyIndent()
        } label: {
            toolbarLabel(
                title: "Indent",
                systemImage: "increase.indent"
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    private var blockquoteButton: some View {
        Button {
            viewModel.toggleBlockquote()
        } label: {
            toolbarLabel(
                title: "인용구",
                systemImage: "text.quote",
                foregroundColor: viewModel.isBlockquote ? Constants.activeColor : Constants.inactiveColor
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    private var listButton: some View {
        Button {
            isListDialogPresented = true
        } label: {
            toolbarLabel(
                title: "목록",
                systemImage: "list.bullet"
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    private func toolbarLabel(
        title: String,
        systemImage: String,
        foregroundColor: Color = Constants.inactiveColor
    ) -> some View {
        HStack(spacing: Constants.labelSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: Constants.iconSize, weight: .semibold))

            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Constants.horizontalPadding)
    }
}
