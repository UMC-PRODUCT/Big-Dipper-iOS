import SwiftUI
import CoreDesignSystem

@main
struct UMCAppApp: App {

    init() {
        CoreDesignSystem.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
