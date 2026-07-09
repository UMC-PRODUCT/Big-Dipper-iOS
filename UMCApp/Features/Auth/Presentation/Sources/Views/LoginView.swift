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
    @AccessibilityFocusState private var isPendingApprovalMessageFocused: Bool

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

            pendingApprovalMessage

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
        // 신규 UX(레거시 부재)라 VoiceOver 포커스를 명시적으로 옮겨 안내 문구를 announce한다.
        if newState == .failed(.auth(.pendingApproval)) {
            isPendingApprovalMessageFocused = true
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

    // MARK: - Subviews

    /// 기존 회원이지만 아직 기수 배정 전(승인 대기)인 경우의 인라인 안내.
    ///
    /// `#911`의 임시 정책에 따라 화면 전환 없이 로그인 화면에 머무르되, 완전히 무반응이지
    /// 않도록 안내 문구를 표시한다.
    @ViewBuilder
    private var pendingApprovalMessage: some View {
        if case .failed(let error) = viewModel.loginState, error == .auth(.pendingApproval) {
            Text(error.userMessage)
                .appFont(.footnote, color: .grey500)
                .multilineTextAlignment(.center)
                .accessibilityFocused($isPendingApprovalMessageFocused)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultSpacing.spacing12)
        }
    }
}
