import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    @State private var router = WatchRouter()
    @State private var inbox = PingInbox()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(router)
                .environment(inbox)
                // WCSession 활성화는 앱당 한 번이면 된다. 활성화가 끝나야 콜드런치 시딩
                // (`receivedApplicationContext`)이 들어오므로 첫 화면 그리기 전에 건다.
                .task { inbox.activate() }
        }
    }
}
