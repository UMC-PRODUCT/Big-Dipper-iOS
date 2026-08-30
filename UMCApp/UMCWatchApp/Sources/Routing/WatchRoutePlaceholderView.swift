// 경로가 실제로 도달 가능한지만 증명하는 최소 화면이다.
// #1207(출석)·#1208(The Ping)·#1209(폴백) 에서 실제 화면으로 교체된다.

import SwiftUI
import CoreWatchDesignSystem

// MARK: - WatchRoutePlaceholderView

struct WatchRoutePlaceholderView: View {

    // MARK: - Property

    let route: WatchRoute

    // MARK: - Body

    var body: some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            Text(route.title)
                .font(.watch(.screenTitle))
                .foregroundStyle(WatchColor.textPrimary)
            Text("준비 중")
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        .watchScreenBackground()
    }
}

#if DEBUG
#Preview("WatchRoutePlaceholderView — 출석 세션") {
    NavigationStack {
        WatchRoutePlaceholderView(route: .attendanceSession(scheduleID: "1024"))
    }
}
#endif
