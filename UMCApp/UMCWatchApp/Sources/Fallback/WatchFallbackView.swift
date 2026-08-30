import CoreWatchDesignSystem
import SwiftUI

// MARK: - WatchFallbackView

/// `WatchRoute.fallback(reason)` 목적지. 실제 표시 형태(전체화면·인라인 카드·배너)는 reason
/// 마다 다르지만(스펙 §5), 이 이슈에서 실제로 도달 가능해야 하는 경로는 라우팅(전체화면)뿐이다
/// — 인라인/배너 형태는 `WatchOfflineQueueCard`·`WatchMandatoryNoticeBanner` 가 각자의 화면에
/// 직접 박힐 때(#1207/#1208) 쓴다.
struct WatchFallbackView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    let reason: WatchFallbackReason

    // MARK: - Body

    var body: some View {
        ScrollView {
            WatchFallbackScene(
                presentation: reason.presentation,
                // "다시 시도" 는 이 폴백을 닫고 요청을 띄운 화면으로 되돌린다 — 폴백 화면은
                // 실패 원인만 알 뿐 재요청 주체를 모른다. 실제 재시도 액션은 #1207 이 붙인다.
                onPrimaryAction: { router.pop() },
                // "iPhone 에서 시도" 는 워치 쪽 시도를 접는 선택이라 스택을 홈까지 비운다 —
                // 되돌아가 봐야 같은 실패를 반복하는 화면뿐이다. iPhone 에서 할 일은 힌트가 말한다.
                onSecondaryAction: { router.popToRoot() }
            )
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .watchScreenBackground()
    }
}

#if DEBUG
#Preview("WatchFallbackView — 위치 권한 거부") {
    NavigationStack {
        WatchFallbackView(reason: .locationPermissionDenied)
    }
    .environment(WatchRouter())
}

#Preview("WatchFallbackView — 출석 요청 실패(재시도 + iPhone 대체)") {
    NavigationStack {
        WatchFallbackView(reason: .checkInRequestFailed)
    }
    .environment(WatchRouter())
}

#Preview("WatchFallbackView — A11y 크기") {
    NavigationStack {
        WatchFallbackView(reason: .checkInWindowClosed)
    }
    .environment(WatchRouter())
    .dynamicTypeSize(.accessibility3)
}
#endif
