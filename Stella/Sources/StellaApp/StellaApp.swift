import SwiftUI
import AppKit

@main
struct StellaApp: App {
    @State private var model = ScanModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // .app 번들로 실행될 때는 Info.plist 의 CFBundleIconFile 이 자동 적용됨.
        // `swift run stella` 처럼 번들 없이 실행될 때만 PNG 를 squircle 마스킹해서
        // Dock 아이콘으로 셋업한다.
        if Bundle.main.bundlePath.hasSuffix(".app") == false,
           let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let raw = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = squircleMasked(raw)
        }
    }

    private func squircleMasked(_ source: NSImage) -> NSImage {
        let canvas: CGFloat = 1024
        let inset: CGFloat = 100
        let inner = canvas - 2 * inset
        let radius = inner * 0.2237

        let sourceSize = source.size
        let side = min(sourceSize.width, sourceSize.height)
        let cropRect = NSRect(
            x: (sourceSize.width - side) / 2,
            y: (sourceSize.height - side) / 2,
            width: side,
            height: side
        )

        let masked = NSImage(size: NSSize(width: canvas, height: canvas))
        masked.lockFocus()
        let innerRect = NSRect(x: inset, y: inset, width: inner, height: inner)
        NSBezierPath(roundedRect: innerRect, xRadius: radius, yRadius: radius).addClip()
        source.draw(in: innerRect, from: cropRect, operation: .copy, fraction: 1)
        masked.unlockFocus()
        return masked
    }

    var body: some Scene {
        WindowGroup("Stella") {
            ContentView(model: model)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("스캔 실행") { Task { await model.runScan() } }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(model.isRunning)
                Button("스냅샷 열기…") { model.openSnapshot() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("스냅샷 저장…") { model.saveSnapshot() }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(model.snapshot == nil)
                Button("owners.yml 저장…") { model.saveOwnersYAML() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!model.canExportOwnersYAML)
            }
        }
    }
}
