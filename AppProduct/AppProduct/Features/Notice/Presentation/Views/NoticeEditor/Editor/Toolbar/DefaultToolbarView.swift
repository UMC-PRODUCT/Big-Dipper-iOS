//
//  DefaultToolbarView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import SwiftUI

/// 공지 에디터의 기본 액세서리 툴바입니다.
struct DefaultToolbarView: View {
    @Bindable var viewModel: EditorToolbarViewModel
    var onInsertTable: () -> Void
    var onTapAI: () -> Void
    var onTapHighlight: () -> Void

    @State private var isListDialogPresented: Bool = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: .zero) {
            formatButton
            listButton
            tableButton
            aiButton
            highlightButton
        }
        .frame(maxWidth: .infinity, minHeight: Constants.toolbarHeight, maxHeight: Constants.toolbarHeight)
    }

    // MARK: - Components

    private var formatButton: some View {
        toolbarButton(
            icon: Constants.formatIcon,
            tint: viewModel.isFormatPanelVisible ? .indigo500 : Constants.inactiveColor,
            action: viewModel.toggleFormatPanel
        )
    }

    private var listButton: some View {
        toolbarButton(icon: Constants.listIcon, action: presentListDialog)
            .confirmationDialog(
                Constants.listDialogTitle,
                isPresented: $isListDialogPresented,
                titleVisibility: .visible
            ) {
                Button(Constants.bulletTitle) {
                    viewModel.applyList(.bullet)
                }

                Button(Constants.dashTitle) {
                    viewModel.applyList(.dash)
                }

                Button(Constants.numberTitle) {
                    viewModel.applyList(.number)
                }

                Button(Constants.cancelTitle, role: .cancel) { }
            }
    }

    private var tableButton: some View {
        toolbarButton(icon: Constants.tableIcon, action: onInsertTable)
    }

    private var aiButton: some View {
        toolbarButton(icon: Constants.aiIcon, action: onTapAI)
    }

    private var highlightButton: some View {
        toolbarButton(icon: Constants.highlightIcon, action: onTapHighlight)
    }

    private func toolbarButton(
        icon: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Constants.iconSize, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: Constants.toolbarHeight, maxHeight: Constants.toolbarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(tint)
        .foregroundStyle(tint)
    }

    private func presentListDialog() {
        isListDialogPresented = true
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let formatIcon: String = "textformat.size"
        static let listIcon: String = "list.bullet"
        static let tableIcon: String = "tablecells"
        static let aiIcon: String = "sparkles"
        static let highlightIcon: String = "highlighter"

        static let listDialogTitle: String = "목록 스타일"
        static let bulletTitle: String = "구분점"
        static let dashTitle: String = "대시선"
        static let numberTitle: String = "숫자"
        static let cancelTitle: String = "취소"

        static let toolbarHeight: CGFloat = 44
        static let iconSize: CGFloat = 18
        static let inactiveColor: Color = .primary
    }
}
