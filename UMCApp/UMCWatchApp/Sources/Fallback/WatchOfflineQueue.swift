import CoreWatchDesignSystem
import Foundation
import SwiftUI

// MARK: - WatchOfflineQueueWindow

/// 오프라인 큐의 유효 시간 계산. 스펙 §3.3 — 서버는 수신 시각 기준 과거 180분 이내만 판정에
/// 쓰고, 워치는 측정 시각 +3시간이 지난 항목을 보내기 전에 스스로 버린다.
enum WatchOfflineQueueWindow {

    /// 측정 시각으로부터의 유효 시간 3시간.
    static let validity: TimeInterval = 3 * 60 * 60

    /// 측정 시각과 현재 시각으로 큐 상태를 판정한다. 순수 함수 — `Date.now` 를 읽지 않는다.
    static func state(measuredAt: Date, now: Date) -> WatchOfflineQueueState {
        let elapsed = now.timeIntervalSince(measuredAt)
        // 측정 시각이 미래(시계 오차 등)면 아직 아무것도 소비되지 않은 것으로 보고 유효 시간을
        // 통째로 남겨 둔다 — 음수 경과를 그대로 빼면 remaining 이 validity 를 넘어 버린다.
        let remaining = validity - max(elapsed, 0)
        guard remaining > 0 else { return .expired }
        return .waiting(remaining: remaining)
    }
}

// MARK: - WatchOfflineQueueState

enum WatchOfflineQueueState: Equatable, Sendable {
    /// 아직 유효 — 남은 시간.
    case waiting(remaining: TimeInterval)
    /// 유효 시간 초과 — 보내지 않고 버린다. 사유 제출로 안내한다.
    case expired

    var reason: WatchFallbackReason { self == .expired ? .offlineQueueExpired : .offlineQueued }
}

// MARK: - WatchOfflineQueueCard

/// P0-7 인라인 카드. 대기/만료는 스펙상 "한 프레임 두 상태"라 화면(컴포넌트)은 하나지만,
/// `WatchOfflineQueueState.reason` 이 문구·아이콘·CTA 를 통째로 갈라 준다.
struct WatchOfflineQueueCard: View {

    // MARK: - Property

    let measuredAt: Date
    let now: Date

    // MARK: - Body

    var body: some View {
        WatchFallbackScene(presentation: presentation)
            .watchCard(state == .expired ? .danger : .standard)
    }

    // MARK: - Function

    private var state: WatchOfflineQueueState {
        WatchOfflineQueueWindow.state(measuredAt: measuredAt, now: now)
    }

    private var presentation: WatchFallbackPresentation {
        switch state {
        case .waiting(let remaining):
            return state.reason.presentation.replacing(hint: Self.remainingLabel(remaining))
        case .expired:
            return state.reason.presentation
        }
    }

    private static func remainingLabel(_ remaining: TimeInterval) -> String {
        let totalMinutes = max(Int(remaining / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "남은 유효 시간 \(hours)시간 \(minutes)분"
    }
}

#if DEBUG
#Preview("WatchOfflineQueueCard — 대기 · 만료") {
    NavigationStack {
        ScrollView {
            VStack(spacing: WatchLayout.stackSpacing) {
                WatchOfflineQueueCard(
                    measuredAt: .now.addingTimeInterval(-60 * 90),
                    now: .now
                )
                WatchOfflineQueueCard(
                    measuredAt: .now.addingTimeInterval(-60 * 200),
                    now: .now
                )
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}
#endif
