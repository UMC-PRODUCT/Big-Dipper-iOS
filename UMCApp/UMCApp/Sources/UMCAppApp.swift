import CoreDesignSystem
import CoreDI
import NoticeData
import NoticePresentation
import SwiftData
import SwiftUI
import UMCFoundation
import os.log

@main
struct UMCAppApp: App {

    // MARK: - Property

    @Environment(\.scenePhase) private var scenePhase
    @State private var container: DIContainer
    @State private var errorHandler: ErrorHandler = .init()
    private let sharedModelContainer: ModelContainer

    // MARK: - Init

    init() {
        CoreDesignSystem.registerFonts()

        sharedModelContainer = Self.makeModelContainer()

        let container = DIContainer.configured(
            modelContext: sharedModelContainer.mainContext
        )
        container.registerNoticeDependencies()
        container.registerAuthDependencies()
        _container = State(initialValue: container)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(errorHandler)
                .environment(\.di, container)
                .modelContainer(sharedModelContainer)
                .alertPrompt(item: errorAlertBinding)
                .onOpenURL(perform: handleOpenURL)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    // TODO: 후속 이슈(#946) - 포그라운드 복귀 시 킬스위치 재확인
                }
        }
    }
}

// MARK: - Private Helpers

extension UMCAppApp {

    /// ErrorHandler의 currentError를 AlertPrompt 바인딩으로 변환합니다.
    private var errorAlertBinding: Binding<AlertPrompt?> {
        Binding(
            get: {
                guard let presentable = errorHandler.currentError else {
                    return nil
                }
                return AlertPrompt(
                    title: presentable.title,
                    message: presentable.message,
                    positiveBtnTitle: presentable.showRetry ? "재시도" : "확인",
                    positiveBtnAction: presentable.showRetry
                        ? { Task { await presentable.retryAction?() } }
                        : nil,
                    negativeBtnTitle: presentable.showRetry ? "닫기" : nil
                )
            },
            set: { newValue in
                if newValue == nil {
                    errorHandler.clearError()
                }
            }
        )
    }

    /// 소셜 로그인 딥링크 URL을 처리합니다.
    ///
    /// - Note: 실제 카카오/구글 리다이렉트 처리는 후속 이슈(#912)에서 연결된다.
    private func handleOpenURL(_ url: URL) {}

    /// SwiftData ModelContainer를 생성합니다.
    ///
    /// - Returns: 생성된 ModelContainer. 로컬 저장소 초기화가 실패하면 인메모리로 폴백한다.
    ///
    /// - Note: `groupContainer: .none` — 위젯 IPC용 App Group 컨테이너를 SwiftData 기본
    ///   스토어 위치로 쓰지 않도록 명시한다. `.automatic`(기본값)은 App Group entitlement가
    ///   있으면 그 공유 컨테이너를 자동 선택해, 최초 실행마다 상위 디렉터리 부재로 인한
    ///   CoreData recovery 로그가 발생했다.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            NoticeReadRecord.self,
            AITokenDailyUsageRecord.self,
        ])

        do {
            let configuration = ModelConfiguration(schema: schema, groupContainer: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let reason = error.localizedDescription
            logger.error("SwiftData local store init failed, falling back to in-memory: \(reason)")
            do {
                let memoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    groupContainer: .none
                )
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("Failed to initialize ModelContainer: \(error)")
            }
        }
    }
}

// MARK: - Logging

extension UMCAppApp {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "UMCApp",
        category: "AppBootstrap"
    )
}
