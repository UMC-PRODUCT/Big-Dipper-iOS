import CoreWatchDesignSystem
import Observation
import SwiftUI

// MARK: - WatchMandatoryNotice

/// 필수 확인 공지. 식별자는 서버 정수를 String 으로 받는다 (절대 규칙 #2).
struct WatchMandatoryNotice: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
}

// MARK: - WatchMandatoryNoticeCenter

/// 필수 확인 공지의 확인 여부를 앱 생명주기 동안 들고 있는 전역 관리자.
/// 절대 규칙 #1 의 예외(앱 생명주기 전역 관리자)라 `@Observable` 을 쓴다.
@Observable
final class WatchMandatoryNoticeCenter {

    // MARK: - Property

    private(set) var pending: WatchMandatoryNotice?

    // MARK: - Function

    func present(_ notice: WatchMandatoryNotice) {
        pending = notice
    }

    /// 사용자가 "확인"을 누른 경우에만 배너가 사라진다. 스와이프·무시 경로는 존재하지 않는다.
    func confirm() {
        pending = nil
    }
}

// MARK: - WatchMandatoryNoticeBanner

/// P0-8 상단 고정 배너. `WatchRootView` 최상위 `safeAreaInset(edge: .top)` 전용이다 —
/// `NavigationStack` 안에 두면 좌측 엣지 스와이프로 pop 돼 "무시 불가" 계약이 깨진다(스펙 §6).
struct WatchMandatoryNoticeBanner: View {

    // MARK: - Property

    let notice: WatchMandatoryNotice
    let onConfirm: () -> Void

    // MARK: - Body

    var body: some View {
        WatchFallbackScene(presentation: presentation, onPrimaryAction: onConfirm)
            .watchCard(leadingAccent: presentation.status.tint)
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
            // 다른 화면 콘텐츠보다 먼저 낭독되도록 헤더 취급 + 정렬 우선순위를 높인다.
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(1)
    }

    // MARK: - Function

    private var presentation: WatchFallbackPresentation {
        WatchFallbackReason.mandatoryNoticeUnread.presentation.replacingMessage(notice.title)
    }
}

#if DEBUG
#Preview("WatchMandatoryNoticeBanner") {
    WatchMandatoryNoticeBanner(
        notice: WatchMandatoryNotice(id: "1", title: "8월 정기 모임 필수 공지"),
        onConfirm: {}
    )
    .watchScreenBackground()
}
#endif
