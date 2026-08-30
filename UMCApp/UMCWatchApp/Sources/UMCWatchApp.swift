import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    @State private var router = WatchRouter()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(router)
        }
    }
}
