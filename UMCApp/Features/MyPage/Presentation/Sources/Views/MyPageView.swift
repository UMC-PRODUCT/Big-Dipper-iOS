//
//  MyPageView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDI
import CoreRouting
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// MyPage 탭 루트 화면.
///
/// 프로필 카드와 ``MyPageSectionType`` 순서의 섹션들을 조립한다. 프로필이 있어야 의미가 있는
/// 섹션(외부 링크·소셜 연동)은 조회가 끝난 뒤에만 노출한다.
///
/// - Important: 자체 `NavigationStack`을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유한다.
struct MyPageView: View {

    // MARK: - Property

    @State private var viewModel: MyPageViewModel

    /// 연동 요청 중인 소셜. 외부 로그인 시트가 떠 있는 동안 중복 탭을 막는 화면 상태다.
    @State private var connectingSocial: SocialType?

    @Environment(PathStore.self) private var pathStore
    @Environment(ErrorHandler.self) private var errorHandler
    @Environment(\.appFlow) private var appFlow

    private let container: DIContainer

    // MARK: - Init

    /// - Parameters:
    ///   - container: 섹션·목적지 화면이 UseCase를 resolve할 DI 컨테이너
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container로 생성)
    init(container: DIContainer, viewModel: MyPageViewModel? = nil) {
        self.container = container
        _viewModel = State(initialValue: viewModel ?? MyPageViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        Form {
            profileContent

            if let profile = viewModel.profileData.value {
                ProfileLinkSection(
                    profileLink: profile.profileLink,
                    alertPrompt: $viewModel.alertPrompt
                )
            }

            MyActiveLogSection(onSelect: { logType in
                pathStore.push(
                    MyPageDestination.myActivePosts(logType: logType),
                    on: .mypage
                )
            })

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
                onChangePassword: {
                    pathStore.push(MyPageDestination.changePassword, on: .mypage)
                },
                onLogout: { endSession("logout", perform: viewModel.logout) },
                onDeleteAccount: { endSession("deleteAccount", perform: viewModel.deleteAccount) }
            )
        }
        .navigation(naviTitle: NavigationTitle.MyPage.root, displayMode: .inline)
        .umcDefaultBackground()
        .alertPrompt(item: $viewModel.alertPrompt)
        .navigationDestination(for: MyPageDestination.self) { destination in
            MyPageRoutingView(destination: destination, container: container)
        }
        .task {
            await viewModel.fetchProfile()
        }
    }

    // MARK: - View Component

    @ViewBuilder
    private var profileContent: some View {
        switch viewModel.profileData {
        case .idle, .loading:
            Progress()
                .frame(maxWidth: .infinity)

        case .loaded(let profile):
            ProfileCardSection(profileData: profile)

        case .failed(let error):
            RetryContentUnavailableView(
                title: "프로필을 불러오지 못했어요",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: error.errorDescription ?? "잠시 후 다시 시도해 주세요.",
                isRetrying: viewModel.profileData.isLoading,
                retryAction: { await viewModel.fetchProfile(forceRefresh: true) }
            )
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
