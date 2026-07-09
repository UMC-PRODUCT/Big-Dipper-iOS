import AuthDomain
import CoreDesignSystem
import CoreDI
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 소셜 로그인 진입 화면.
///
/// 기존 회원은 바로 로그인되고, 신규 회원은 `appFlow.showSignUp(...)`을 통해
/// 회원가입 화면으로 전환된다.
public struct LoginView: View {

    // MARK: - Property

    @State private var viewModel: LoginViewModel
    @Environment(\.appFlow) private var appFlow

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(
            initialValue: LoginViewModel(container: container, errorHandler: errorHandler)
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: .zero) {
            Spacer()

            AuthLogoBlock()
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            Spacer()

            LoginActionStack(
                isLoading: viewModel.loginState.isLoading,
                onKakaoTap: { Task { await viewModel.loginWithKakao() } },
                onAppleTap: { viewModel.loginWithApple() },
                onGoogleTap: { Task { await viewModel.loginWithGoogle() } }
            )
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
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
