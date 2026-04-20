//
//  DefaultToolbarView.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

/// 공지 에디터의 기본 액세서리 툴바입니다.
struct DefaultToolbarView: View {
    @Bindable var viewModel: EditorToolbarViewModel
    var onTapAI: () -> Void
    var onTapHighlight: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: .zero) {
            formatButton
            boldButton
            italicButton
            underlineButton
            strikethroughButton
            aiButton
            highlightButton
            listButton
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
        Menu {
            Button {
                viewModel.applyList(.bullet)
            } label: {
                Label(Constants.bulletTitle, systemImage: "list.bullet")
            }

            Button {
                viewModel.applyList(.dash)
            } label: {
                Label(Constants.dashTitle, systemImage: "list.dash")
            }

            Button {
                viewModel.applyList(.number)
            } label: {
                Label(Constants.numberTitle, systemImage: "list.number")
            }
        } label: {
            Image(systemName: Constants.listIcon)
                .font(.system(size: Constants.iconSize, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: Constants.toolbarHeight, maxHeight: Constants.toolbarHeight)
                .contentShape(Rectangle())
                .foregroundStyle(Constants.inactiveColor)
        }
    }

    private var boldButton: some View {
        inlineFormatButton(title: "B", weight: .bold, isActive: viewModel.isBold, action: viewModel.toggleBold)
    }

    private var italicButton: some View {
        inlineFormatButton(title: "I", weight: .regular, isItalic: true, isActive: viewModel.isItalic, action: viewModel.toggleItalic)
    }

    private var underlineButton: some View {
        inlineFormatButton(title: "U", weight: .regular, isUnderline: true, isActive: viewModel.isUnderline, action: viewModel.toggleUnderline)
    }

    private var strikethroughButton: some View {
        inlineFormatButton(title: "S", weight: .regular, isStrikethrough: true, isActive: viewModel.isStrikethrough, action: viewModel.toggleStrikethrough)
    }

    private func inlineFormatButton(
        title: String,
        weight: Font.Weight,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Constants.iconSize, weight: weight).italic(isItalic))
                .underline(isUnderline)
                .strikethrough(isStrikethrough)
                .frame(maxWidth: .infinity, minHeight: Constants.toolbarHeight, maxHeight: Constants.toolbarHeight)
                .contentShape(Rectangle())
                .foregroundStyle(isActive ? Color.indigo500 : Constants.inactiveColor)
        }
        .buttonStyle(.plain)
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

    // MARK: - Constants

    fileprivate enum Constants {
        static let formatIcon: String = "textformat.size"
        static let listIcon: String = "list.bullet"
        static let aiIcon: String = "sparkles"
        static let highlightIcon: String = "highlighter"

        static let bulletTitle: String = "구분점"
        static let dashTitle: String = "대시선"
        static let numberTitle: String = "숫자"

        static let toolbarHeight: CGFloat = 44
        static let iconSize: CGFloat = 18
        static let inactiveColor: Color = .primary
    }
}
