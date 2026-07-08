import AuthDomain
import CoreDesignSystem
import CoreDI
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 소셜 로그인 진입 화면 — 기존 회원만 로그인 가능하다 (신규 회원 가입 플로우는 `#944` 스코프).
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
            guard case .loaded = newState else { return }
            appFlow.showMain()
        }
        .alertPrompt(item: $viewModel.alertPrompt)
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
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
                .padding(.bottom, DefaultSpacing.spacing12)
        }
    }
}
