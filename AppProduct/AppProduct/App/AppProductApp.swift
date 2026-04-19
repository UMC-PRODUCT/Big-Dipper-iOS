//
//  AppProductApp.swift
//  AppProduct
//
//  Created by jaewon Lee on 12/30/25.
//

import CloudKit
import KakaoSDKAuth
import KakaoSDKCommon
import SwiftData
import SwiftUI
import TipKit

@main
struct AppProductApp: App {

    // MARK: - Property

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container: DIContainer
    @State private var didConfigureAppDelegate: Bool = false
    @State private var errorHandler: ErrorHandler = .init()
    @State private var appState: AppState = .splash
    private let sharedModelContainer: ModelContainer

    // MARK: - AppState

    private enum AppState: Equatable {
        case splash
        case login
        case signUp(
            verificationToken: String,
            email: String?,
            fullName: String?,
            postRegisterLoginContext: PostRegisterLoginContext?
        )
        case pendingApproval
        case main
    }
    
    init() {
        sharedModelContainer = Self.makeModelContainer()
        KakaoSDK.initSDK(appKey: Config.kakaoAppKey)
        _container = State(
            initialValue: DIContainer.configured(
                modelContext: sharedModelContainer.mainContext
            )
        )
        try? Tips.configure()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            rootView
                .onOpenURL(perform: handleOpenURL)
                .environment(errorHandler)
                .environment(\.di, container)
                .environment(\.appFlow, appFlow)
                .modelContainer(sharedModelContainer)
                .alertPrompt(item: errorAlertBinding)
                .onAppear(perform: configureAppDelegateIfNeeded)
                .onReceive(
                    NotificationCenter.default.publisher(for: .authSessionExpired)
                ) { _ in
                    handleAuthSessionExpired()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .navigateToPendingApproval)
                ) { _ in
                    transition(to: .pendingApproval)
                }
        }
    }
}

// MARK: - Private Helpers

extension AppProductApp {
    @ViewBuilder
    private var rootView: some View {
        ZStack {
            switch appState {
            case .splash:
                SplashView(
                    networkClient: container.resolve(NetworkClient.self),
                    fetchMyProfileUseCase: container.resolve(
                        HomeUseCaseProviding.self
                    ).fetchMyProfileUseCase,
                    tokenStore: container.resolve(TokenStore.self)
                )
                .transition(rootTransition)

            case .login:
                LoginView(
                    loginUseCase: authProvider.loginUseCase,
                    fetchMyProfileUseCase: container.resolve(
                        HomeUseCaseProviding.self
                    ).fetchMyProfileUseCase,
                    tokenStore: container.resolve(TokenStore.self),
                    errorHandler: errorHandler
                )
                .transition(rootTransition)

            case .signUp(
                let verificationToken,
                let email,
                let fullName,
                let postRegisterLoginContext
            ):
                SignUpView(
                    oAuthVerificationToken: verificationToken,
                    initialEmail: email,
                    initialName: fullName,
                    postRegisterLoginContext: postRegisterLoginContext,
                    sendEmailVerificationUseCase: authProvider
                        .sendEmailVerificationUseCase,
                    verifyEmailCodeUseCase: authProvider
                        .verifyEmailCodeUseCase,
                    registerUseCase: authProvider.registerUseCase,
                    loginUseCase: authProvider.loginUseCase,
                    fetchSignUpDataUseCase: authProvider.fetchSignUpDataUseCase
                )
                .transition(rootTransition)

            case .pendingApproval:
                FailedVerificationUMC()
                    .transition(rootTransition)

            case .main:
                UmcTab()
                    .transition(rootTransition)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appState)
    }
    
    private var authProvider: AuthUseCaseProviding {
        container.resolve(AuthUseCaseProviding.self)
    }

    private func transition(to state: AppState) {
        guard state != appState else { return }
        withAnimation {
            appState = state
        }
    }

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

    private var rootTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
    
    /// 카카오 로그인 딥링크 URL을 처리합니다.
    private func handleOpenURL(_ url: URL) {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return }
        _ = AuthController.handleOpenUrl(url: url)
    }
    
    private func configureAppDelegateIfNeeded() {
        guard !didConfigureAppDelegate else { return }
        didConfigureAppDelegate = true
        appDelegate.configure(
            container: container,
            modelContext: sharedModelContainer.mainContext
        )
    }
    
    private func handleAuthSessionExpired() {
        UserDefaults.standard.set(false, forKey: AppStorageKey.canAutoLogin)
        Task {
            try? await container.resolve(NetworkClient.self).logout()
        }
        container.resetCache()
        transition(to: .login)
    }

    private var appFlow: AppFlow {
        AppFlow(
            showLogin: { transition(to: .login) },
            showMain: { transition(to: .main) },
            showSignUp: {
                verificationToken,
                email,
                fullName,
                postRegisterLoginContext in
                transition(
                    to: .signUp(
                        verificationToken: verificationToken,
                        email: email,
                        fullName: fullName,
                        postRegisterLoginContext: postRegisterLoginContext
                    )
                )
            },
            showPendingApproval: { transition(to: .pendingApproval) },
            logout: { handleAuthSessionExpired() }
        )
    }
    
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            NoticeHistoryData.self,
            GenerationMappingRecord.self,
            NoticeReadRecord.self,
            AITokenDailyUsageRecord.self
        ])
        
        do {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(
                for: schema,
                configurations: [cloudConfiguration]
            )
        } catch {
            print("SwiftData CloudKit init failed. Fallback to local store: \(error)")
            
            do {
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(
                    for: schema,
                    configurations: [localConfiguration]
                )
            } catch {
                print("SwiftData local init failed. Fallback to in-memory store: \(error)")
                do {
                    let memoryConfiguration = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                    return try ModelContainer(
                        for: schema,
                        configurations: [memoryConfiguration]
                    )
                } catch {
                    fatalError("Failed to initialize ModelContainer: \(error)")
                }
            }
        }
    }
}
