//
//  LoginView.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/9/26.
//

import AuthDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 로그인 진입 화면.
///
/// 기존 회원은 바로 로그인되고, 신규 회원은 `appFlow.showSignUp(...)`을 통해
/// 회원가입 화면으로 전환된다. UMC 계정(ID/PW) 로그인은 이 화면의 `NavigationStack`에서
/// `EmailLoginView`를 push해 처리한다.
public struct LoginView: View {

    // MARK: - Property

    @State private var viewModel: LoginViewModel
    @State private var isEmailLoginPresented = false
    @Environment(\.appFlow) private var appFlow

    /// 이메일 로그인 화면을 push할 때 그대로 전달하기 위해 보관한다.
    private let container: DIContainer
    private let errorHandler: ErrorHandler

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
        _viewModel = State(
            initialValue: LoginViewModel(container: container, errorHandler: errorHandler)
        )
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: .zero) {
                Spacer()

                AuthLogoBlock()
                    .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

                Spacer()

                LoginActionStack(
                    isLoading: viewModel.loginState.isLoading,
                    onKakaoTap: { Task { await viewModel.loginWithKakao() } },
                    onAppleTap: { viewModel.loginWithApple() },
                    onGoogleTap: { Task { await viewModel.loginWithGoogle() } },
                    onEmailTap: { isEmailLoginPresented = true }
                )
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultConstant.defaultSafeBottom)
            }
            // 루트에는 표시할 네비게이션 바가 없다. 숨기지 않으면 빈 바 높이만큼 safe area 가
            // 줄어 `BootstrapView` 의 `.loginReady` layout 과 로고 위치가 어긋난다.
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isEmailLoginPresented) {
                EmailLoginView(container: container, errorHandler: errorHandler)
            }
        }
        .onChange(of: viewModel.loginState) { _, newState in
            handle(newState: newState)
        }
        .onChange(of: viewModel.signUpDestination) { _, newDestination in
            handle(signUpDestination: newDestination)
        }
    }

    // MARK: - Function

    private func handle(newState: Loadable<Profile>) {
        if case .loaded = newState {
            appFlow.showMain()
        }
        if newState == .failed(.auth(.pendingApproval)) {
            appFlow.showPendingApproval()
        }
    }

    private func handle(signUpDestination: SignUpDestination?) {
        guard let signUpDestination else { return }
        appFlow.showSignUp(
            signUpDestination.verificationToken,
            signUpDestination.email,
            signUpDestination.fullName,
            signUpDestination.postRegisterLoginContext
        )
    }
}
