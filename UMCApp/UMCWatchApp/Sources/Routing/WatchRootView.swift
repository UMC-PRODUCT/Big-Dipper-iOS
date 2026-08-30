import SwiftUI

// MARK: - WatchRootView

/// 워치 앱의 단일 `NavigationStack` 셸. 모든 목적지를 여기 한 곳에서 등록한다.
struct WatchRootView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router

    // MARK: - Body

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeGlanceView()
                .navigationDestination(for: WatchRoute.self) { destination(for: $0) }
        }
    }

    // MARK: - Function

    /// 아직 화면이 없는 경로는 플레이스홀더로 남는다 — #1207(출석)·#1209(폴백)가 채운다.
    @ViewBuilder
    private func destination(for route: WatchRoute) -> some View {
        switch route {
        case .pingList:
            PingListView()
        case .pingDetail(let noticeID):
            PingDetailView(noticeID: noticeID)
        case .attendanceList, .attendanceSession, .attendanceResult, .fallback:
            WatchRoutePlaceholderView(route: route)
        }
    }
}
