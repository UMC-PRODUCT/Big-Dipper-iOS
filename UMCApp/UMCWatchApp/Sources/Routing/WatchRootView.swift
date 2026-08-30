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
                .navigationDestination(for: WatchRoute.self) { route in
                    WatchRoutePlaceholderView(route: route)
                }
        }
    }
}
