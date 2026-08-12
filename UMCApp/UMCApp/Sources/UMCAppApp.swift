//
//  UMCAppApp.swift
//  UMCApp
//
//  Created by euijjang97 on 3/6/26.
//

import CoreDesignSystem
import CoreDI
import FirebaseCore
import GoogleSignIn
import HomeData
import HomeDomain
import KakaoSDKAuth
import KakaoSDKCommon
import MaintenancePresentation
import NoticeDomain
import NoticeData
import NoticePresentation
import SwiftData
import SwiftUI
import TipKit
import UMCFoundation
import os.log

@main
struct UMCAppApp: App {

    // MARK: - Property

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var container: DIContainer
    @State private var errorHandler: ErrorHandler = .init()
    @State private var maintenanceViewModel: MaintenanceViewModel
    private let sharedModelContainer: ModelContainer

    // MARK: - Init

    init() {
        CoreDesignSystem.registerFonts()
        KakaoSDK.initSDK(appKey: Config.Auth.kakaoKey)
        Self.configureFirebaseIfNeeded()

        sharedModelContainer = Self.makeModelContainer()

        let container = DIContainer.configured(
            modelContext: sharedModelContainer.mainContext
        )
        container.registerNoticeDependencies()
        container.registerMemberProfileDependencies()
        container.registerAuthorizationDependencies()
        container.registerAuthDependencies()
        container.registerHomeDependencies(
            modelContext: sharedModelContainer.mainContext
        )
        container.registerActivityDependencies()
        container.registerCommunityDependencies()
        container.registerMyPageDependencies()
        container.registerMaintenanceDependencies()
        #if DEBUG
        // 카카오 로그인 서버 미등록 기간 한정 stub 세션 (StubSessionMode.swift 단일 토글).
        // 실제 등록 뒤 · 최초 resolve 전에 호출해야 오버라이드가 안전하다 (last-wins).
        if StubSessionMode.isEnabled {
            container.registerStubSessionOverrides()
        }
        #endif
        _container = State(initialValue: container)
        // RemoteConfig 접근은 lazy이므로, FirebaseApp.configure() 이전에 이 ViewModel을
        // 만들어도 실제 RemoteConfig 인스턴스는 생성되지 않는다.
        _maintenanceViewModel = State(initialValue: MaintenanceViewModel(container: container))
        try? Tips.configure()
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
                .fullScreenCover(isPresented: maintenanceOverlayBinding) {
                    if let overlayKind = maintenanceViewModel.overlayKind {
                        MaintenanceView(kind: overlayKind)
                    }
                }
                .task {
                    appDelegate.configure(
                        container: container,
                        modelContext: sharedModelContainer.mainContext
                    )
                    await maintenanceViewModel.check()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await maintenanceViewModel.check() }
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

    /// 킬스위치·강제 업데이트 오버레이의 `fullScreenCover` 바인딩.
    ///
    /// 사용자가 스와이프 등으로 임의로 닫을 수 없도록 `set`을 no-op으로 둔다. 오버레이는
    /// 서버 재확인 결과 `overlayKind`가 `nil`이 될 때만 ViewModel에 의해 자동으로 사라진다.
    private var maintenanceOverlayBinding: Binding<Bool> {
        Binding(
            get: { maintenanceViewModel.overlayKind != nil },
            set: { _ in }
        )
    }

    /// 소셜 로그인 딥링크 URL을 처리합니다.
    private func handleOpenURL(_ url: URL) {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            AuthController.handleOpenUrl(url: url)
            return
        }
        GIDSignIn.sharedInstance.handle(url)
    }

    /// `GoogleService-Info.plist`가 유효할 때만 `FirebaseApp`을 구성합니다.
    ///
    /// - Note: CI 등 시크릿(plist)이 배포되지 않은 환경에서도 빌드·실행이 깨지지 않도록,
    ///   plist 부재/파싱 실패/플레이스홀더 값(`GOOGLE_APP_ID`가 `__`로 시작)이면 조용히
    ///   건너뛴다. 이 경우 RemoteConfig는 항상 fail-open으로 동작한다
    ///   (`MaintenanceData.RemoteConfigService` 참고).
    ///
    /// - Note: `AppDelegate.didFinishLaunchingWithOptions`도 `Messaging` 접근 전에 이 메서드를
    ///   호출한다. 두 진입점의 호출 순서는 보장되지 않지만 `FirebaseApp.app()` 가드로 멱등이다.
    static func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        guard
            let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plistData = NSDictionary(contentsOfFile: plistPath),
            let googleAppID = plistData["GOOGLE_APP_ID"] as? String,
            !googleAppID.isEmpty,
            !googleAppID.hasPrefix("__")
        else {
            logger.error("GoogleService-Info.plist가 없거나 유효하지 않아 Firebase 구성을 건너뜁니다.")
            return
        }
        FirebaseApp.configure()
    }

    /// SwiftData ModelContainer를 생성합니다.
    ///
    /// CloudKit(`iCloud.com.umc.product`) 동기화를 먼저 시도하고, 실패하면 로컬 →
    /// 인메모리 순으로 폴백한다. (레거시 v2.2.0과 동일한 3단 체인)
    ///
    /// - Returns: 생성된 ModelContainer.
    ///
    /// - Note: `groupContainer: .none` — 위젯 IPC용 App Group 컨테이너를 SwiftData 기본
    ///   스토어 위치로 쓰지 않도록 명시한다. `.automatic`(기본값)은 App Group entitlement가
    ///   있으면 그 공유 컨테이너를 자동 선택해, 최초 실행마다 상위 디렉터리 부재로 인한
    ///   CoreData recovery 로그가 발생했다.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            NoticeReadRecord.self,
            AITokenDailyUsageRecord.self,
            NoticeHistoryData.self,
            GenerationMappingRecord.self,
        ])

        do {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: .none,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let cloudReason = error.localizedDescription
            logger.error("SwiftData CloudKit init failed, falling back to local: \(cloudReason)")
        }

        do {
            let localConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            let reason = error.localizedDescription
            logger.error("SwiftData local store init failed, falling back to in-memory: \(reason)")
            do {
                let memoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    groupContainer: .none,
                    cloudKitDatabase: .none
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
