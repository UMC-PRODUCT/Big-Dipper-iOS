import CoreWatchConnectivity
import SwiftUI

// MARK: - WatchRootView

/// 워치 앱의 단일 `NavigationStack` 셸. 모든 목적지를 여기 한 곳에서 등록한다.
struct WatchRootView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    @Environment(WatchMandatoryNoticeCenter.self) private var noticeCenter

    // MARK: - Body

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeGlanceView()
                .navigationDestination(for: WatchRoute.self) { route in
                    destination(for: route)
                }
        }
        .safeAreaInset(edge: .top) {
            // `NavigationStack` 밖 최상위에 붙인다 — 스택 안이면 좌측 엣지 스와이프로 pop 돼
            // "확인 전까지 무시 불가" 계약이 깨진다(스펙 §6). 확인 전까지는 화면을 옮겨도 계속 떠 있다.
            if let notice = noticeCenter.pending {
                WatchMandatoryNoticeBanner(notice: notice, onConfirm: noticeCenter.confirm)
            }
        }
    }

    // MARK: - Function

    @ViewBuilder
    private func destination(for route: WatchRoute) -> some View {
        switch route {
        case .attendanceList, .attendanceSession, .attendanceResult, .pingList, .pingDetail:
            WatchRoutePlaceholderView(route: route)
        case .fallback(let reason):
            WatchFallbackView(reason: reason)
        }
    }
}

#if DEBUG
#Preview("WatchRootView — P0-8 배너가 홈 위에 고정") {
    let noticeCenter = WatchMandatoryNoticeCenter()
    noticeCenter.present(WatchMandatoryNotice(id: "1", title: "8월 정기 모임 필수 공지"))

    return WatchRootView()
        .environment(WatchRouter())
        .environment(WatchSessionCoordinator())
        .environment(noticeCenter)
}
#endif
