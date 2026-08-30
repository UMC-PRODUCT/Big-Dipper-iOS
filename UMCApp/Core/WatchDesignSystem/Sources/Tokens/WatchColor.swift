import SwiftUI

// MARK: - WatchColor

/// watchOS 전용 색 토큰.
///
/// OLED 순수 블랙 배경을 전제로 한 값이라 appearance 분기가 없다(워치는 항상 dark).
/// iOS `CoreDesignSystem/Resources/Colors.xcassets` 와 값을 공유하는 것은 브랜드 4종 +
/// 중립 회색 1종뿐이며, 그 정합은 `WatchColorTokenTests` 가 잠근다.
/// 시맨틱 상태색 3종은 iOS 와 **의도적으로 다르다** — 검정 배경 대비를 위해 Apple 다크
/// 시스템 팔레트를 쓴다(iOS: #33A881/#FFA500/#DD4646).
public enum WatchColor {

    // MARK: - Background

    /// 화면 전체 배경. OLED 픽셀 소등(배터리·번인) 목적의 순수 블랙. (#000000)
    public static let screen           = Color(sRGBHex: WatchColorHex.screen)
    /// 일반 카드 배경 — 불투명 solid. Glass 금지 구역. (#16181C)
    public static let cardBackground   = Color(sRGBHex: WatchColorHex.cardBackground)
    /// 일반 카드 보더. (#2A2D34)
    public static let cardBorder       = Color(sRGBHex: WatchColorHex.cardBorder)
    /// Hero(대표 지표) 카드 배경. (#1B2140)
    public static let heroBackground   = Color(sRGBHex: WatchColorHex.heroBackground)
    /// Hero 카드 보더 = 브랜드 인디고 45% (rgba(72,105,240,.45)).
    public static let heroBorder       = brandPrimary.opacity(0.45)
    /// 위험/파괴적 맥락 카드 배경. (#241416)
    public static let dangerBackground = Color(sRGBHex: WatchColorHex.dangerBackground)
    /// 위험 카드 보더 = 에러 레드 40% (rgba(255,69,58,.4)).
    public static let dangerBorder     = statusError.opacity(0.40)

    // MARK: - Brand

    /// Primary Indigo. CTA tint·active 상태·Hero 보더. (iOS indigo500 · #4869F0)
    public static let brandPrimary = Color(sRGBHex: WatchColorHex.brandPrimary)
    /// 검정/다크 카드 위에 얹는 브랜드색 텍스트·아이콘용 밝은 단계. (iOS indigo400 · #6683FF)
    public static let brandPrimaryHighlight = Color(sRGBHex: WatchColorHex.brandPrimaryHighlight)
    /// 가장 밝은 단계 — pending 링, 저강조 보조 강조. (iOS indigo300 · #99ABFF)
    public static let brandPrimarySoft = Color(sRGBHex: WatchColorHex.brandPrimarySoft)
    /// Accent Orange — **The Ping 배지·브랜드 강조 전용**. (iOS orange500 · #FF731A)
    /// 상태(성공/경고/실패)를 표현하는 데 절대 쓰지 않는다. 상태는 `status*` 를 쓴다.
    public static let brandAccent = Color(sRGBHex: WatchColorHex.brandAccent)

    // MARK: - Status (브랜드색과 분리된 시맨틱 축)

    /// 진행 중/활성. 브랜드 인디고와 같은 값이지만 **의미가 다르므로 별도 이름**으로 참조한다.
    public static let statusActive  = brandPrimary
    /// 승인 대기 — 회색 점 + 인디고 링(`WatchStatusBadge` 가 palette 렌더링으로 합성). (#B2B8BF)
    public static let statusPending = neutralGrey
    /// 완료. (#30D158)
    public static let statusSuccess = Color(sRGBHex: WatchColorHex.statusSuccess)
    /// 주의. (#FFB340)
    public static let statusWarning = Color(sRGBHex: WatchColorHex.statusWarning)
    /// 실패. (#FF453A)
    public static let statusError   = Color(sRGBHex: WatchColorHex.statusError)

    // MARK: - Text

    /// 본문·강조 텍스트. (#FFFFFF)
    public static let textPrimary   = Color(sRGBHex: WatchColorHex.textPrimary)
    /// 보조 텍스트·캡션. (#B2B8BF)
    public static let textSecondary = neutralGrey
    /// 비활성 컨트롤 라벨. 새 리터럴을 만들지 않고 보조 텍스트를 감쇠시킨다.
    public static let textDisabled  = neutralGrey.opacity(0.5)

    // MARK: - Private

    /// `textSecondary` 와 `statusPending` 이 공유하는 단일 회색 리터럴. (iOS grey400 · #B2B8BF)
    private static let neutralGrey = Color(sRGBHex: WatchColorHex.neutralGrey)
}

// MARK: - WatchColorHex

/// 팔레트 원본값(sRGB 24bit). `WatchColor` 가 유일한 소비자이고,
/// 테스트가 `@testable import` 로 읽어 iOS asset catalog 와 대조한다.
enum WatchColorHex {
    static let screen: UInt32                = 0x000000
    static let cardBackground: UInt32        = 0x16181C
    static let cardBorder: UInt32            = 0x2A2D34
    static let heroBackground: UInt32        = 0x1B2140
    static let dangerBackground: UInt32      = 0x241416

    static let brandPrimary: UInt32          = 0x4869F0
    static let brandPrimaryHighlight: UInt32 = 0x6683FF
    static let brandPrimarySoft: UInt32      = 0x99ABFF
    static let brandAccent: UInt32           = 0xFF731A

    static let statusSuccess: UInt32         = 0x30D158
    static let statusWarning: UInt32         = 0xFFB340
    static let statusError: UInt32           = 0xFF453A

    static let textPrimary: UInt32           = 0xFFFFFF
    static let neutralGrey: UInt32           = 0xB2B8BF
}

// MARK: - Color + sRGBHex

private extension Color {
    /// 0xRRGGBB sRGB 리터럴로 색을 만든다. 워치는 appearance 분기가 없어 이 한 벌로 충분하다.
    init(sRGBHex hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255,
            opacity: 1
        )
    }
}
