import CoreWatchConnectivity
import SwiftUI

// MARK: - WatchRootView

/// 워치 앱의 단일 `NavigationStack` 셸. 모든 목적지를 여기 한 곳에서 등록한다.
struct WatchRootView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    @Environment(WatchMandatoryNoticeCenter.self) private var noticeCenter
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
        .safeAreaInset(edge: .top) {
            // `NavigationStack` 밖 최상위에 붙인다 — 스택 안이면 좌측 엣지 스와이프로 pop 돼
            // "확인 전까지 무시 불가" 계약이 깨진다(스펙 §6). 확인 전까지는 화면을 옮겨도 계속 떠 있다.
            if let notice = noticeCenter.pending {
                WatchMandatoryNoticeBanner(notice: notice, onConfirm: noticeCenter.confirm)
            }
        }
    }

    // MARK: - Function

    /// 일정 식별자를 실제 일정으로 풀지 못하면 플레이스홀더로 떨어진다 — 딥링크나 푸시로
    /// 먼저 도착했는데 iPhone 이 아직 일정을 밀어주지 않은 경우다.
    /// The Ping(#1208)은 아직 플레이스홀더가 정상이다.
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

        case .pingList, .pingDetail:
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
        .environment(WatchAttendanceViewModel())
}
#endif
