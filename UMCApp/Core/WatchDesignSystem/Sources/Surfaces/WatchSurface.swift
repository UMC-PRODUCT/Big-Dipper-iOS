import SwiftUI

// MARK: - WatchCardStyle

/// 카드 표면 종류. **전부 불투명 solid** 이며 Glass 배리언트는 존재하지 않는다.
/// 콘텐츠 배경 Glass 금지 규칙을 타입 수준에서 강제하기 위한 닫힌 집합이다.
public enum WatchCardStyle: Sendable, CaseIterable {
    /// 일반 카드 — #16181C / border #2A2D34
    case standard
    /// 대표 지표·다음 일정 등 Hero — #1B2140 / border 인디고 45%
    case hero
    /// 위험·실패·파괴적 맥락 — #241416 / border 에러 레드 40%
    case danger
}

// MARK: - WatchCardStyle + Palette

extension WatchCardStyle {

    var fill: Color {
        switch self {
        case .standard: WatchColor.cardBackground
        case .hero:     WatchColor.heroBackground
        case .danger:   WatchColor.dangerBackground
        }
    }

    var border: Color {
        switch self {
        case .standard: WatchColor.cardBorder
        case .hero:     WatchColor.heroBorder
        case .danger:   WatchColor.dangerBorder
        }
    }
}

// MARK: - WatchSurfaceShape

enum WatchSurfaceShape {

    static var shape: ConcentricRectangle {
        ConcentricRectangle(
            corners: .concentric(minimum: WatchLayout.cardCornerRadius),
            isUniform: true
        )
    }

    static func border(_ color: Color) -> some View {
        shape.stroke(color, lineWidth: WatchLayout.cardBorderWidth)
    }
}

// MARK: - WatchLayout + Shape

public extension WatchLayout {

    /// 카드와 동일한 곡률. 중첩 콘텐츠 clip·히트영역(`contentShape`) 정합용.
    static var cardShape: ConcentricRectangle { WatchSurfaceShape.shape }
}

// MARK: - WatchSurface

/// `watchListRowBackground` 전용 표면 뷰 — `List` 행 배경은 뷰 하나로 넘겨야 한다.
/// `watchCard` 는 콘텐츠를 감싸는 모디파이어 체인이라 이 뷰를 쓰지 않고,
/// 보더 렌더링만 `WatchSurfaceShape.border(_:)` 로 공유한다.
struct WatchSurface: View {

    // MARK: - Property

    let style: WatchCardStyle

    // MARK: - Body

    var body: some View {
        WatchSurfaceShape.shape
            .fill(style.fill)
            .overlay { WatchSurfaceShape.border(style.border) }
    }
}

// MARK: - View + Watch Surface

public extension View {

    /// 워치 공통 카드. 패딩·불투명 배경·1pt 보더·동심 모서리를 한 번에 적용한다.
    ///
    /// - Parameters:
    ///   - style: 표면 종류 (기본 `.standard`).
    ///   - leadingAccent: 좌측 색바 색. `nil`이면 그리지 않는다.
    ///     긴급 공지처럼 **색 이외의 위치 신호**가 필요할 때만 쓴다 (#1208).
    func watchCard(
        _ style: WatchCardStyle = .standard,
        leadingAccent: Color? = nil
    ) -> some View {
        // accent bar 를 background 와 clipShape 사이에 끼워야 모서리 안쪽으로 잘린다.
        // 보더는 clipShape 뒤에 얹어야 1pt 가 온전히 남는다 — ConcentricRectangle 은
        // InsettableShape 가 아니라 strokeBorder 를 쓸 수 없어 stroke + overlay 조합이다.
        //
        // containerShape 는 붙이지 않는다: SDK 상 concentric 곡률을 containerShape 로 전달할
        // 방법이 없고(ConcentricRectangle 이 RoundedRectangularShape 비채택), 리터럴 22 을
        // 선언하면 실제 해석값(디스플레이 곡률 기반, 22 초과)과 달라 자식이 틀린 값을 상속한다.
        // 중첩 콘텐츠는 `WatchLayout.cardShape` 로 직접 맞춘다.
        self
            .padding(WatchLayout.cardContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.fill)
            .overlay(alignment: .leading) {
                if let leadingAccent {
                    leadingAccent.frame(width: WatchLayout.accentBarWidth)
                }
            }
            .clipShape(WatchSurfaceShape.shape)
            .contentShape(WatchSurfaceShape.shape)
            .overlay { WatchSurfaceShape.border(style.border) }
    }

    /// 화면 전체 배경을 순수 블랙(#000000)으로 고정한다.
    /// watchOS 기본 네비게이션 그라디언트 배경을 덮는다.
    ///
    /// - Important: `NavigationStack` **destination 의 최상위 콘텐츠**에 적용한다.
    func watchScreenBackground() -> some View {
        containerBackground(WatchColor.screen, for: .navigation)
    }

    /// `List` 행 배경. 기본 시스템 행 배경(반투명)을 불투명 solid 로 교체한다 —
    /// 리스트 행은 Glass 금지 구역이다.
    ///
    /// - Parameter isSelected: `true`면 Hero 표면(인디고 tint) + 좌측 색바로 선택을 표현한다.
    ///   Hero fill 단독은 standard 대비 명암비가 1.13:1 에 그쳐 저시력·야외에서 식별되지
    ///   않으므로, 색과 분리된 위치 신호를 함께 준다 (#1207 선택행).
    func watchListRowBackground(isSelected: Bool = false) -> some View {
        listRowBackground(
            WatchSurface(style: isSelected ? .hero : .standard)
                .overlay(alignment: .leading) {
                    if isSelected {
                        WatchColor.brandPrimary
                            .frame(width: WatchLayout.accentBarWidth)
                    }
                }
                .clipShape(WatchSurfaceShape.shape)
        )
    }
}

#if DEBUG
#Preview("WatchSurface — 카드 3종 + accent bar") {
    NavigationStack {
        ScrollView {
            VStack(spacing: WatchLayout.stackSpacing) {
                ForEach(Array(WatchCardStyle.allCases.enumerated()), id: \.offset) { _, style in
                    VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                        Text(String(describing: style))
                            .font(.watch(.cardLabel))
                            .foregroundStyle(WatchColor.textSecondary)
                        Text("12:30")
                            .font(.watch(.cardValue))
                            .foregroundStyle(WatchColor.textPrimary)
                    }
                    .watchCard(style)
                }

                Text("긴급 공지 — 좌측 색바")
                    .font(.watch(.cardValue))
                    .foregroundStyle(WatchColor.textPrimary)
                    .watchCard(leadingAccent: WatchColor.brandAccent)
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}
#endif
