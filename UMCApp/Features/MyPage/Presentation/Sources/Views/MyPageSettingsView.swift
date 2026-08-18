//
//  MyPageSettingsView.swift
//  MyPagePresentation
//
//  Created by One on 8/18/26.
//

import CoreDI
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// 마이페이지 설정 화면.
///
/// 루트(``MyPageView``)에 있던 프로필 링크·시스템 설정·약관·앱 정보·소셜 연동·인증·UMC 채널
/// 섹션이 여기로 옮겨온다. v3 루트가 명함 카드로 바뀌면서 이 섹션들은 더 이상 루트에 직접
/// 노출되지 않고 설정 진입점(⚙) 뒤로 들어간다.
///
/// 프로필이 있어야 의미가 있는 섹션(외부 링크·소셜 연동)은 조회가 끝난 뒤에만 노출한다 —
/// 탭 루트와 같은 방식이다.
///
/// - Important: 자체 `NavigationStack`을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유한다.
struct MyPageSettingsView: View {

    // MARK: - Property

    @State private var viewModel: MyPageViewModel

    /// 연동 요청 중인 소셜. 외부 로그인 시트가 떠 있는 동안 중복 탭을 막는 화면 상태다.
    @State private var connectingSocial: SocialType?

    @Environment(ErrorHandler.self) private var errorHandler
    @Environment(\.appFlow) private var appFlow

    private let container: DIContainer

    // MARK: - Init

    /// - Parameter container: 섹션이 UseCase를 resolve할 DI 컨테이너
    init(container: DIContainer) {
        self.container = container
        _viewModel = State(initialValue: MyPageViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        Form {
            if let profile = viewModel.profileData.value {
                ProfileLinkSection(
                    profileLink: profile.profileLink,
                    alertPrompt: $viewModel.alertPrompt
                )
            }

            SettingSection()
            LawSection()
            InfoSection()

            if let profile = viewModel.profileData.value {
                SocialConnectSection(
                    connectedSocials: profile.socialConnected,
                    connectingSocial: connectingSocial,
                    onConnect: connect
                )
            }

            AuthSection(
                alertPrompt: $viewModel.alertPrompt,
                onLogout: { endSession("logout", perform: viewModel.logout) },
                onDeleteAccount: { endSession("deleteAccount", perform: viewModel.deleteAccount) }
            )

            UMCChannelSection()
        }
        .navigation(naviTitle: NavigationTitle.MyPage.settings, displayMode: .inline)
        .umcDefaultBackground()
        .alertPrompt(item: $viewModel.alertPrompt)
        .task {
            await viewModel.fetchProfile()
        }
    }

    // MARK: - Function

    /// 소셜 연동을 요청하고 결과를 프로필 상태에 반영한다.
    private func connect(_ social: SocialType) {
        guard connectingSocial == nil else { return }
        connectingSocial = social

        Task {
            defer { connectingSocial = nil }

            do {
                try await viewModel.connectSocial(social)
            } catch {
                errorHandler.handle(
                    error,
                    context: ErrorContext(
                        feature: "MyPage",
                        action: "connectSocial(\(social.rawValue))"
                    )
                )
            }
        }
    }

    /// 세션을 끝내는 액션(로그아웃·탈퇴)을 수행하고 로그인 화면으로 되돌린다.
    ///
    /// ViewModel은 절대규칙 #1에 따라 `AppFlow`를 들고 있지 않으므로 전환은 여기서 한다.
    private func endSession(
        _ actionName: String,
        perform: @MainActor @escaping () async throws -> Void
    ) {
        Task {
            do {
                try await perform()
                appFlow.logout()
            } catch {
                errorHandler.handle(
                    error,
                    context: ErrorContext(feature: "MyPage", action: actionName)
                )
            }
        }
    }
}
