import SwiftUI

// MARK: - WatchStatus

/// 시맨틱 상태 축. 브랜드 색(`WatchColor.brandAccent` 등)과 **분리**되어 있다.
/// 각 케이스는 색뿐 아니라 **실루엣이 다른** SF Symbol 을 가진다 —
/// 색각 이상 사용자가 색 없이도 구분할 수 있어야 한다.
///
/// `Equatable` 은 #1209 `WatchFallbackPresentation` 이 이 타입을 담고도 구조체 전체를
/// `Equatable` 로 합성하기 위해 필요하다 — 연관값 없는 enum 이라 비교 로직은 자동 합성된다.
public enum WatchStatus: Sendable, CaseIterable, Equatable {
    /// 진행 중 — 인디고 원판.
    case active
    /// 승인 대기 — 회색 점 + 인디고 링(팔레트 렌더링).
    case pending
    /// 완료 — 체크.
    case success
    /// 주의 — 삼각형.
    case warning
    /// 실패 — 팔각형.
    case error

    /// 상태 색. `pending` 은 점 색이고, 링 색은 `ringTint` 다.
    public var tint: Color {
        switch self {
        case .active:  WatchColor.statusActive
        case .pending: WatchColor.statusPending
        case .success: WatchColor.statusSuccess
        case .warning: WatchColor.statusWarning
        case .error:   WatchColor.statusError
        }
    }

    /// 2차 색 — `pending` 의 인디고 링에만 쓰인다. 그 외에는 `tint` 와 같다.
    /// `active` 원판(`brandPrimary`)과 같은 인디고를 쓰면 라벨 없는 경로에서 둘이 섞이므로
    /// 한 단계 밝은 `brandPrimarySoft` 를 쓴다.
    public var ringTint: Color {
        self == .pending ? WatchColor.brandPrimarySoft : tint
    }

    /// 실루엣이 서로 다른 심볼. 색을 못 봐도 구분되도록 고른 값이다.
    /// 원판 / 점+링 / 원안체크 / 삼각형 / 팔각형.
    public var symbolName: String {
        switch self {
        case .active:  "circle.fill"
        case .pending: "smallcircle.filled.circle"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error:   "xmark.octagon.fill"
        }
    }

    /// 화면이 문구를 주지 않을 때 쓰는 기본 라벨.
    public var defaultLabel: String {
        switch self {
        case .active:  "진행 중"
        case .pending: "승인 대기"
        case .success: "완료"
        case .warning: "주의"
        case .error:   "실패"
        }
    }
}

// MARK: - WatchStatusBadge

/// 상태 표시. **색 단독으로 상태를 표현하지 않는다** — 심볼 실루엣이 다르고,
/// 기본적으로 텍스트를 병기한다.
///
/// - `showsLabel: true`  — 심볼 + 텍스트. 심볼은 `accessibilityHidden`, 전체를 하나의
///   접근성 요소로 합쳐 텍스트만 낭독한다.
/// - `showsLabel: false` — 리스트 행처럼 폭이 없는 자리용. 심볼만 그리되
///   `accessibilityLabel` 로 같은 문구를 반드시 노출한다.
public struct WatchStatusBadge: View {

    // MARK: - Property

    private let status: WatchStatus
    private let label: String?
    private let showsLabel: Bool

    private var resolvedLabel: String { label ?? status.defaultLabel }

    // MARK: - Init

    public init(
        _ status: WatchStatus,
        label: String? = nil,
        showsLabel: Bool = true
    ) {
        self.status = status
        self.label = label
        self.showsLabel = showsLabel
    }

    // MARK: - Body

    public var body: some View {
        if showsLabel {
            HStack(spacing: WatchLayout.tightSpacing) {
                symbol.accessibilityHidden(true)
                Text(resolvedLabel)
                    .font(.watch(.cardLabel))
                    .foregroundStyle(WatchColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
        } else {
            symbol.accessibilityLabel(resolvedLabel)
        }
    }

    // MARK: - Function

    private var symbol: some View {
        Image(systemName: status.symbolName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(status.tint, status.ringTint)
            .font(.watch(.cardLabel))
    }
}

#if DEBUG
#Preview("WatchStatusBadge — 5 상태 × 라벨 유무") {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchLayout.stackSpacing) {
                ForEach(Array(WatchStatus.allCases.enumerated()), id: \.offset) { _, status in
                    HStack(spacing: WatchLayout.stackSpacing) {
                        WatchStatusBadge(status)
                        Spacer(minLength: 0)
                        WatchStatusBadge(status, showsLabel: false)
                    }
                }
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}
#endif
