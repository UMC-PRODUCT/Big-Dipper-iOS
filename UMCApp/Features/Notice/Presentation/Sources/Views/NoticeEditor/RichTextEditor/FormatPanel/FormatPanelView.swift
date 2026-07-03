//
//  FormatPanelView.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/30/26.
//

import SwiftUI
import UIKit
import CoreDesignSystem

fileprivate struct HighlightOption {
    let name: String
    let color: Color
}

fileprivate enum Constants {
    static let containerSpacing: CGFloat = 20
    static let containerPadding: CGFloat = 20
    static let containerCornerRadius: CGFloat = 16
    static let paragraphSpacing: CGFloat = 10
    static let paragraphRowVerticalPadding: CGFloat = 2
    static let paragraphHorizontalPadding: CGFloat = 16
    static let paragraphVerticalPadding: CGFloat = 10
    static let controlSpacing: CGFloat = 8
    static let controlButtonSize: CGFloat = 38
    static let controlCornerRadius: CGFloat = 10
    static let closeButtonSize: CGFloat = 34
    static let indicatorSize: CGFloat = 16
    static let paletteSpacing: CGFloat = 8
    static let paletteTopPadding: CGFloat = 8
    static let paletteCircleSize: CGFloat = 24
    static let activeColor: Color = .indigo500
    static let inactiveBackgroundColor: Color = .secondary.opacity(0.14)
    static let inactiveForegroundColor: Color = .secondary
    static let activeForegroundColor: Color = .white
    static let paragraphStyles: [EditorParagraphStyle] = [.title, .heading, .subheading, .body, .mono]
    static let highlightPalette: [HighlightOption] = [
        .init(name: "보라", color: .purple.opacity(0.35)),
        .init(name: "분홍", color: .pink.opacity(0.35)),
        .init(name: "주황", color: .orange.opacity(0.35)),
        .init(name: "민트", color: .mint.opacity(0.35)),
        .init(name: "파랑", color: .blue.opacity(0.35))
    ]
}

/// 공지 에디터에서 단락/인라인/목록 서식을 제어하는 패널
public struct FormatPanelView: View {

    // MARK: - Property

    @Bindable var viewModel: EditorToolbarViewModel
    @State private var isHighlightPalettePresented = false

    /// ViewModel의 highlightColor와 팔레트 색상을 비교하여 현재 선택된 인덱스를 반환합니다.
    private var selectedHighlightIndex: Int? {
        guard let vmColor = viewModel.highlightColor else { return nil }
        return Constants.highlightPalette.firstIndex { colorsApproximatelyEqual($0.color, vmColor) }
    }

    private var selectedHighlightColor: Color? {
        viewModel.highlightColor
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Constants.containerSpacing) {
            header
            paragraphRow
            inlineRow
            listRow
        }
        .padding(Constants.containerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text("포맷")
                .appFont(.body, weight: .semibold ,color: .black)

            Spacer()

            Button(action: viewModel.dismissFormatPanel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: Constants.closeButtonSize, height: Constants.closeButtonSize)
                    .foregroundStyle(.secondary)
                    .background(Constants.inactiveBackgroundColor, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("포맷 패널 닫기")
        }
    }

    // MARK: - Row1 Paragraph

    private var paragraphRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.paragraphSpacing) {
                ForEach(Constants.paragraphStyles, id: \.self) { style in
                    Button {
                        viewModel.applyParagraphStyle(style)
                    } label: {
                        Text(paragraphTitle(for: style))
                            .font(paragraphPreviewFont(for: style))
                            .foregroundStyle(paragraphForegroundColor(for: style))
                            .lineLimit(1)
                            .padding(.horizontal, Constants.paragraphHorizontalPadding)
                            .padding(.vertical, Constants.paragraphVerticalPadding)
                            .background(paragraphBackground(for: style), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(paragraphTitle(for: style))
                }
            }
            .padding(.vertical, Constants.paragraphRowVerticalPadding)
        }
    }

    // MARK: - Row2 Inline

    private var inlineRow: some View {
        HStack(alignment: .top, spacing: Constants.containerSpacing) {
            HStack(spacing: Constants.controlSpacing) {
                formatToggleButton(
                    title: "B",
                    previewStyle: .bold,
                    isActive: viewModel.isBold,
                    accessibilityLabel: "굵게"
                ) {
                    viewModel.toggleBold()
                }

                formatToggleButton(
                    title: "I",
                    previewStyle: .italic,
                    isActive: viewModel.isItalic,
                    accessibilityLabel: "기울임"
                ) {
                    viewModel.toggleItalic()
                }

                formatToggleButton(
                    title: "U",
                    previewStyle: .underline,
                    isActive: viewModel.isUnderline,
                    accessibilityLabel: "밑줄"
                ) {
                    viewModel.toggleUnderline()
                }

                formatToggleButton(
                    title: "S",
                    previewStyle: .strikethrough,
                    isActive: viewModel.isStrikethrough,
                    accessibilityLabel: "취소선"
                ) {
                    viewModel.toggleStrikethrough()
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: Constants.paletteTopPadding) {
                HStack(spacing: Constants.controlSpacing) {
                    iconButton(
                        systemName: "highlighter",
                        isActive: isHighlightPalettePresented,
                        accessibilityLabel: "형광펜 색상 선택"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHighlightPalettePresented.toggle()
                        }
                    }

                    Circle()
                        .fill(selectedHighlightColor ?? Color.clear)
                        .frame(width: Constants.indicatorSize, height: Constants.indicatorSize)
                        .overlay {
                            if selectedHighlightColor == nil {
                                Image(systemName: "line.diagonal")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Constants.inactiveForegroundColor)
                            }
                            Circle()
                                .stroke(Constants.inactiveForegroundColor.opacity(0.18), lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }

                if isHighlightPalettePresented {
                    HStack(spacing: Constants.paletteSpacing) {
                        Button {
                            viewModel.clearHighlight()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHighlightPalettePresented = false
                            }
                        } label: {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: Constants.paletteCircleSize, height: Constants.paletteCircleSize)
                                .overlay {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Constants.inactiveForegroundColor)
                                    Circle()
                                        .stroke(
                                            selectedHighlightIndex == nil ? Constants.activeColor : Constants.inactiveForegroundColor.opacity(0.3),
                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("형광펜 제거")

                        ForEach(Array(Constants.highlightPalette.enumerated()), id: \.offset) { index, option in
                            Button {
                                viewModel.applyHighlight(color: option.color)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isHighlightPalettePresented = false
                                }
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: Constants.paletteCircleSize, height: Constants.paletteCircleSize)
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                selectedHighlightIndex == index ? Constants.activeColor : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.name) 형광펜")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Row3 List

    private var listRow: some View {
        HStack(spacing: Constants.controlSpacing) {
            iconButton(
                systemName: "list.bullet",
                accessibilityLabel: "글머리 기호 목록"
            ) {
                viewModel.applyList(.bullet)
            }

            iconButton(
                systemName: "list.dash",
                accessibilityLabel: "대시 목록"
            ) {
                viewModel.applyList(.dash)
            }

            iconButton(
                systemName: "list.number",
                accessibilityLabel: "숫자 목록"
            ) {
                viewModel.applyList(.number)
            }

            iconButton(
                systemName: "text.quote",
                isActive: viewModel.isBlockquote,
                accessibilityLabel: "인용구"
            ) {
                viewModel.toggleBlockquote()
            }
        }
    }

    // MARK: - Private

    private func paragraphPreviewFont(for style: EditorParagraphStyle) -> Font {
        switch style {
        case .title:
            return .system(size: 22, weight: .bold)
        case .heading:
            return .system(size: 17, weight: .bold)
        case .subheading:
            return .system(size: 15, weight: .semibold)
        case .body:
            return .system(size: 15, weight: .regular)
        case .mono:
            return .system(size: 14, weight: .regular, design: .monospaced)
        }
    }

    private func paragraphTitle(for style: EditorParagraphStyle) -> String {
        switch style {
        case .title:
            return "제목"
        case .heading:
            return "머리말"
        case .subheading:
            return "부머리말"
        case .body:
            return "본문"
        case .mono:
            return "모노"
        }
    }

    private func paragraphBackground(for style: EditorParagraphStyle) -> Color {
        viewModel.paragraphStyle == style ? Constants.activeColor : Constants.inactiveBackgroundColor
    }

    private func paragraphForegroundColor(for style: EditorParagraphStyle) -> Color {
        viewModel.paragraphStyle == style ? Constants.activeForegroundColor : Constants.inactiveForegroundColor
    }

    private enum InlineFormatStyle {
        case bold, italic, underline, strikethrough
    }

    private func formatToggleButton(
        title: String,
        previewStyle: InlineFormatStyle,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(previewFont(for: previewStyle))
                .underline(previewStyle == .underline)
                .strikethrough(previewStyle == .strikethrough)
                .frame(width: Constants.controlButtonSize, height: Constants.controlButtonSize)
                .foregroundStyle(isActive ? Constants.activeForegroundColor : Constants.inactiveForegroundColor)
                .background(buttonBackground(isActive: isActive))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func previewFont(for style: InlineFormatStyle) -> Font {
        switch style {
        case .bold:       return .system(size: 18, weight: .bold)
        case .italic:     return .system(size: 18, weight: .regular).italic()
        case .underline:  return .system(size: 16, weight: .regular)
        case .strikethrough: return .system(size: 16, weight: .regular)
        }
    }

    private func iconButton(
        systemName: String,
        isActive: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: Constants.controlButtonSize, height: Constants.controlButtonSize)
                .foregroundStyle(isActive ? Constants.activeForegroundColor : Constants.inactiveForegroundColor)
                .background(buttonBackground(isActive: isActive))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func buttonBackground(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: Constants.controlCornerRadius, style: .continuous)
            .fill(isActive ? Constants.activeColor : Constants.inactiveBackgroundColor)
    }

    /// SwiftUI Color 간 근사 비교 (opacity 포함 RGBA 비교)
    private func colorsApproximatelyEqual(_ lhs: Color, _ rhs: Color) -> Bool {
        let lhsResolved = UIColor(lhs).resolvedColor(with: UITraitCollection.current)
        let rhsResolved = UIColor(rhs).resolvedColor(with: UITraitCollection.current)
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        guard lhsResolved.getRed(&lr, green: &lg, blue: &lb, alpha: &la),
              rhsResolved.getRed(&rr, green: &rg, blue: &rb, alpha: &ra) else {
            return false
        }
        let tolerance: CGFloat = 0.02
        return abs(lr - rr) < tolerance && abs(lg - rg) < tolerance
            && abs(lb - rb) < tolerance && abs(la - ra) < tolerance
    }
}
