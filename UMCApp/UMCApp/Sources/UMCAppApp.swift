import SwiftUI
import CoreDesignSystem
import CoreDI

@main
struct UMCAppApp: App {

    init() {
        CoreDesignSystem.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // TODO: [#816] 피처 화면 조립 시 DI 주입 배선 완성 — 현재 `\.di`는 스캐폴딩 상태.
                // SwiftData 도입 후 앱 루트의 ModelContext를 넘겨 아래 형태로 주입:
                // .environment(\.di, DIContainer.configured(modelContext: modelContext))
        }
    }
}
