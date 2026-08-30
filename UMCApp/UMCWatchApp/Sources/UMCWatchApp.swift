import CoreWatchConnectivity
import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    @State private var router = WatchRouter()
    @State private var sessionCoordinator = WatchSessionCoordinator()
    @State private var noticeCenter = WatchMandatoryNoticeCenter()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(router)
                .environment(sessionCoordinator)
                .environment(noticeCenter)
                .task {
                    // 앱 생명주기 동안 한 번만 활성화한다. 반복 호출해도 안전하지만
                    // 델리게이트 재할당이 매번 일어나 상태 전이 타이밍이 흔들릴 수 있다.
                    sessionCoordinator.activate()
                }
        }
    }
}
