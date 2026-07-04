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
//                .environment(\.di, DIContainer.configured(modelContext:))
        }
    }
}
