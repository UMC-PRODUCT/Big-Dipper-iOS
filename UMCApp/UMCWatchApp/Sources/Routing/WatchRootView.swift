import SwiftUI

// MARK: - WatchRootView

/// 워치 앱의 단일 `NavigationStack` 셸. 모든 목적지를 여기 한 곳에서 등록한다.
struct WatchRootView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    @Environment(WatchAttendanceViewModel.self) private var attendance

    // MARK: - Body

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeGlanceView()
                .navigationDestination(for: WatchRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    // MARK: - Function

    /// 일정 식별자를 실제 일정으로 풀지 못하면 플레이스홀더로 떨어진다 — 딥링크나 푸시로
    /// 먼저 도착했는데 iPhone 이 아직 일정을 밀어주지 않은 경우다.
    /// The Ping(#1208)·폴백(#1209)은 아직 플레이스홀더가 정상이다.
    @ViewBuilder
    private func destination(for route: WatchRoute) -> some View {
        switch route {
        case .attendanceList:
            WatchAttendanceListView()

        case .attendanceSession(let scheduleID):
            if let schedule = attendance.schedule(id: scheduleID) {
                WatchAttendanceSessionView(schedule: schedule)
            } else {
                WatchRoutePlaceholderView(route: route)
            }

        case .attendanceResult(let scheduleID):
            if let schedule = attendance.schedule(id: scheduleID) {
                WatchAttendanceResultView(
                    schedule: schedule,
                    outcome: attendance.outcome(for: scheduleID)
                )
            } else {
                WatchRoutePlaceholderView(route: route)
            }

        case .pingList, .pingDetail, .fallback:
            WatchRoutePlaceholderView(route: route)
        }
    }
}
