//
//  ChipButton.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - ChipButton

/// 선택 상태를 표시하는 칩 형태의 버튼 컴포넌트
///
/// 필터링, 카테고리 선택, 태그 표시 등에 사용합니다.
/// `action`이 nil이면 인터랙션 없는 읽기 전용 태그로 동작합니다.
///
/// ## 사용 예시
///
/// **기본 사용 (인터랙티브 버튼)**
/// ```swift
/// ChipButton("iOS", isSelected: selected) {
///     selected.toggle()
/// }
/// .buttonSize(.medium)
/// .buttonStyle(.filter)
/// ```
///
/// **아이콘 포함**
/// ```swift
/// // Leading 아이콘 (SF Symbol)
/// ChipButton("링크", isSelected: true, leadingIcon: "link") { }
///
/// // Trailing chevron (드롭다운 표시용)
/// ChipButton("전체", isSelected: false, trailingIcon: true) { }
/// ```
///
/// **읽기 전용 태그 (action 생략)**
/// ```swift
/// ChipButton("Week 1", isSelected: false)
/// ```
///
/// ## 사이즈 옵션 (`buttonSize`)
///
/// | Size | Font | Padding | 용도 |
/// |------|------|---------|------|
/// | `.small` | footnote | 8pt | 컴팩트한 태그, 뱃지 |
/// | `.medium` | subheadline | 16pt | 일반 필터, 선택 버튼 |
/// | `.large` | callout | 16pt | 강조 버튼 |
///
/// ## 스타일 옵션 (`buttonStyle`)
///
/// | Style | 선택 시 | 미선택 시 | 용도 |
/// |-------|--------|----------|------|
/// | `.filter` | indigo500/grey000 | grey200/grey600 | 공지 리스트 필터 |
/// | `.board` | indigo500/grey000 | grey300/grey000 | 게시판 분류 선택 |
/// | `.fame` | yellow500/white | white/grey600 | 명예의전당 주차 선택 |
///
/// - Important: `buttonSize()`와 `buttonStyle()`은 반드시 ChipButton에 직접 적용해야 합니다.
///   다른 컨테이너 뷰에 적용하면 Environment 전파가 되지 않습니다.
///
/// - Note: Liquid Glass 효과가 자동 적용됩니다.
///   인터랙티브 버튼은 `.interactive()`, 읽기 전용은 `.identity` 사용.
public struct ChipButton: View {

    // MARK: - Properties

    /// 버튼에 표시될 텍스트
    private let title: String

    /// 선택 상태 여부 (선택 시 스타일 변경)
    private let isSelected: Bool
    private let leadingIcon: String?
    private let trailingIcon: Bool?
    private let action: (() -> Void)?

    /// Environment로 주입되는 버튼 크기 스타일
    @Environment(\.chipButtonSize) private var size

    /// Environment로 주입되는 버튼 컬러 스타일
    @Environment(\.chipButtonStyle) private var style

    // MARK: - Initializer

    /// ChipButton 생성자
    ///
    /// - Parameters:
    ///   - title: 버튼 텍스트
    ///   - isSelected: 선택 상태
    ///   - trailingIcon: 트레일링 아이콘 표시 여부
    ///   - action: 탭 액션 (nil이면 읽기 전용 태그로 동작)
    public init(
        _ title: String,
        isSelected: Bool,
        leadingIcon: String? = nil,
        trailingIcon: Bool? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        if let action = action {
            Button(action: action) {
                ChipButtonContent(
                    title: title,
                    size: size,
                    style: style,
                    isSelected: isSelected,
                    leadingIcon: leadingIcon,
                    trailingIcon: trailingIcon,
                    isInteractive: true
                )
                .equatable()
            }
        } else {
            ChipButtonContent(
                title: title,
                size: size,
                style: style,
                isSelected: isSelected,
                leadingIcon: leadingIcon,
                trailingIcon: trailingIcon,
                isInteractive: false
            )
            .equatable()
        }
    }
}

// MARK: - ChipButtonContent (Presenter)

/// ChipButton의 Presenter 컴포넌트
///
/// Container-Presenter 패턴을 적용하여 렌더링 성능을 최적화합니다.
/// Equatable 구현으로 불필요한 재렌더링을 방지합니다.
private struct ChipButtonContent: View, Equatable {

    // MARK: - Property

    /// 버튼 텍스트
    let title: String

    /// 버튼 크기 스타일
    let size: ChipButtonSize

    /// 버튼 컬러 스타일
    let style: ChipButtonStyle

    /// 선택 상태 여부
    let isSelected: Bool
    let leadingIcon: String?
    let trailingIcon: Bool?
    let isInteractive: Bool
    
    // MARK: - Constant

    fileprivate enum Constants {
        /// chevron 아이콘 크기
        static let chevronSize: CGFloat = 10

        /// 버튼 상하 패딩
        static let btnVerticalPadding: CGFloat = 8
    }

    // MARK: - Equatable

    /// Equatable 비교 구현
    ///
    /// trailingIcon은 클로저가 아니므로 비교에 포함됩니다.
    static func == (lhs: ChipButtonContent, rhs: ChipButtonContent) -> Bool {
        lhs.title == rhs.title &&
        lhs.size == rhs.size &&
        lhs.style == rhs.style &&
        lhs.isSelected == rhs.isSelected &&
        lhs.leadingIcon == rhs.leadingIcon &&
        lhs.trailingIcon == rhs.trailingIcon &&
        lhs.isInteractive == rhs.isInteractive
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(title)
            if trailingIcon == true {
                Image(systemName: "chevron.down")
                    .font(.system(size: Constants.chevronSize))
            }
        }
        .foregroundStyle(style.textColor(isSelected: isSelected))
        .font(size.font)
        .padding(.horizontal, size.horizonPadding)
        .padding(.vertical, Constants.btnVerticalPadding)
        .background(
            Capsule()
                .fill(style.bgColor(isSelected: isSelected))
        )
        .glassEffect(
            isInteractive ? .clear.interactive() : .identity,
            in: Capsule()
        )
    }
}

// MARK: - ChipButton + AnyChipButton

extension ChipButton: AnyChipButton {}
