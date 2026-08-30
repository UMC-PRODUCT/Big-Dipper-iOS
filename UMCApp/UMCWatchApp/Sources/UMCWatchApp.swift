import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    @State private var router = WatchRouter()

    /// 출석 목록·세션·결과가 같은 일정 집합과 결과 캐시를 보도록 앱 셸이 소유한다.
    @State private var attendance = WatchAttendanceViewModel()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(router)
                .environment(attendance)
        }
    }
}
