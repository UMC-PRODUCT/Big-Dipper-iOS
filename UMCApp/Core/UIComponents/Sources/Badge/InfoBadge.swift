//
//  InfoBadge.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 7/15/26.
//

import CoreDesignSystem
import SwiftUI

// MARK: - InfoBadge

/// 텍스트 뱃지 컴포넌트
///
/// Glass Effect 기반의 간결한 정보 뱃지를 표시합니다.
public struct InfoBadge: View, Equatable {

    // MARK: - Constants

    fileprivate enum Constants {
        static let backgroundOpacity: Double = 0.15
    }

    // MARK: - Property

    private let text: String
    private let textColor: Color
    private let tintColor: Color?
    private let glassVariant: GlassVariant

    /// Glass Effect 변형 타입
    public enum GlassVariant: Equatable {
        case regular
        case clear
    }

    // MARK: - Initializer

    /// - Parameters:
    ///   - text: 뱃지에 표시할 텍스트
    ///   - textColor: 텍스트 색상
    ///   - tintColor: Glass Effect 틴트 색상
    ///   - glassVariant: Glass Effect 변형 타입
    public init(
        _ text: String,
        textColor: Color = .grey600,
        tintColor: Color? = nil,
        glassVariant: GlassVariant = .clear
    ) {
        self.text = text
        self.textColor = textColor
        self.tintColor = tintColor
        self.glassVariant = glassVariant
    }

    // MARK: - Body

    public var body: some View {
        switch (glassVariant, tintColor) {
        case (.regular, let color?):
            badgeText.glassEffect(
                .regular.tint(color.opacity(Constants.backgroundOpacity))
            )
        case (.regular, nil):
            badgeText.glassEffect(.regular)
        case (.clear, let color?):
            badgeText.glassEffect(
                .clear.tint(color.opacity(Constants.backgroundOpacity))
            )
        case (.clear, nil):
            badgeText.glassEffect(.clear)
        }
    }

    // MARK: - View Components

    private var badgeText: some View {
        Text(text)
            .appFont(.footnote, color: textColor)
            .lineLimit(1)
            .padding(DefaultConstant.iconPadding)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: DefaultSpacing.spacing8) {
        InfoBadge("중앙대")
        InfoBadge("Leader", tintColor: .gray)
        InfoBadge("iOS", textColor: .indigo500, tintColor: .indigo)
        InfoBadge("미디어 위", glassVariant: .clear)
    }
    .padding()
}
