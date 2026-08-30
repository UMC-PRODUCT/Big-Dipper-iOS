import CoreWatchConnectivity
import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    @State private var router = WatchRouter()

    /// 세션은 앱 수명 하나다. 화면이 소유하면 화면 전환마다 새 코디네이터가 생기고
    /// `WCSession.default.delegate` 는 옛 인스턴스를 가리킨 채로 남는다.
    @State private var coordinator = WatchSessionCoordinator()

    @State private var noticeCenter = WatchMandatoryNoticeCenter()

    /// 출석 목록·세션·결과가 같은 일정 집합과 결과 캐시를 보도록 앱 셸이 소유한다.
    @State private var attendance = WatchAttendanceViewModel()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(router)
                .environment(coordinator)
                .environment(noticeCenter)
                .environment(attendance)
                .task { coordinator.activate() }
        }
    }
}
