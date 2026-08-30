import SwiftUI

// MARK: - WatchTextRole

/// 워치 타이포 스케일 5단계. 전부 **시스템 폰트(SF)** 이고 `Font.TextStyle` 에 매핑돼
/// 워치 설정의 텍스트 크기(Dynamic Type)를 그대로 따라간다.
/// 괄호 안 pt 는 기본 크기에서의 실현값이며, 워치 크기·사용자 설정에 따라 스케일된다.
/// 버튼 라벨은 watchOS 버튼 스타일의 기본 폰트를 존중해 이 스케일에 포함하지 않는다.
public enum WatchTextRole: Sendable, CaseIterable {
    /// 화면 타이틀 — SF Semibold (≈22pt).
    case screenTitle
    /// 대형 지표(출석 카운트다운·인원수) — SF Rounded Semibold + 등폭 숫자 (≈34pt).
    case metric
    /// 카드 라벨 — SF Medium (≈13pt).
    case cardLabel
    /// 카드 값 — SF Regular (≈16pt).
    case cardValue
    /// 캡션·보조 설명 — SF Regular (≈12pt).
    case caption
}

// MARK: - Font + watch

public extension Font {

    /// 워치 타이포 토큰. `.font(.watch(.screenTitle))` 형태로 쓴다.
    ///
    /// 고정 pt(`Font.system(size:)`)를 쓰지 않는 이유: Dynamic Type 에 반응하지 않는다.
    /// `.extraLargeTitle` 은 watchOS 에서 unavailable 이라 `metric` 은 `.largeTitle` 을 쓴다.
    static func watch(_ role: WatchTextRole) -> Font {
        switch role {
        case .screenTitle:
            return .system(.title2, design: .default, weight: .semibold)
        case .metric:
            return .system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
        case .cardLabel:
            return .system(.caption, design: .default, weight: .medium)
        case .cardValue:
            return .system(.body, design: .default, weight: .regular)
        case .caption:
            return .system(.caption2, design: .default, weight: .regular)
        }
    }
}
