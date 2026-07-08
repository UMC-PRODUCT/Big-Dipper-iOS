import CoreDesignSystem
import CoreDI
import NoticeData
import NoticePresentation
import SwiftData
import SwiftUI
import UMCFoundation

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
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            NoticeReadRecord.self,
            AITokenDailyUsageRecord.self,
        ])

        do {
            let configuration = ModelConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("SwiftData local init failed. Fallback to in-memory store: \(error)")
            do {
                let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("Failed to initialize ModelContainer: \(error)")
            }
        }
    }
}
