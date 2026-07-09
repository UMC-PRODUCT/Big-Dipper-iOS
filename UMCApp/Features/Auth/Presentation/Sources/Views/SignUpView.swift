import AuthDomain
import CoreDesignSystem
import CoreDI
import SwiftUI
import UMCFoundation

/// 소셜 신규회원 가입 화면 — 이름/닉네임/이메일/학교/약관을 입력받아 가입을 완료한다.
///
/// Task 3에서 만들어진 섹션 컴포넌트(`SignUpNameNicknameSection` 등)를 조립하는 역할만
/// 담당하며, 각 섹션의 내부 레이아웃/검증 로직은 해당 컴포넌트가 책임진다.
public struct SignUpView: View {

    // MARK: - Property

    @State private var viewModel: SignUpViewModel
    @State private var alertPrompt: AlertPrompt?
    @FocusState private var focusedField: SignUpFocusField?
    @Environment(\.appFlow) private var appFlow

    // MARK: - Constant

    fileprivate enum Constants {
        static let naviSubtitle: String = "동아리 활동을 위해 정보를 입력해주세요."
        static let submitTitle: String = "완료"
        static let completedTitle: String = "가입이 완료됐어요"
        static let pendingApprovalMessage: String =
            "운영진 승인 후 서비스를 이용할 수 있어요. 잠시만 기다려주세요."
        static let manualLoginMessage: String =
            "세션 연결에 실패했어요. 로그인 화면에서 다시 로그인해주세요."
        static let confirmTitle: String = "로그인으로 이동"
    }

    // MARK: - Init

    public init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        verificationToken: String,
        initialEmail: String? = nil,
        initialFullName: String? = nil,
        postRegisterLoginContext: PostRegisterLoginContext? = nil
    ) {
        _viewModel = State(initialValue: SignUpViewModel(
            container: container,
            errorHandler: errorHandler,
            verificationToken: verificationToken,
            initialEmail: initialEmail,
            initialFullName: initialFullName,
            postRegisterLoginContext: postRegisterLoginContext
        ))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DefaultSpacing.spacing24) {
                    SignUpNameNicknameSection(
                        name: $viewModel.name,
                        nickname: $viewModel.nickname,
                        focusBinding: $focusedField,
                        onNicknameSubmit: { focusedField = nil }
                    )

                    SignUpEmailSection(
                        email: $viewModel.email,
                        isVerified: $viewModel.isEmailVerified,
                        onVerificationRequested: {
                            try await viewModel.requestEmailVerification()
                        },
                        onVerificationComplete: { code in
                            try await viewModel.verifyEmailCode(code)
                        },
                        onResend: {
                            try await viewModel.resendEmailVerification()
                        },
                        onEmailChanged: {
                            viewModel.handleEmailChanged()
                        }
                    )

                    SignUpSchoolSection(
                        schoolsState: viewModel.schoolsState,
                        selectedSchool: $viewModel.selectedSchool
                    )

                    SignUpTermsSection(
                        termsState: viewModel.termsState,
                        termsAgreements: viewModel.termsAgreements,
                        isAllTermsAgreed: viewModel.isAllTermsAgreed,
                        onToggleAll: { viewModel.toggleAllTerms($0) },
                        onToggleRow: { viewModel.toggleTerm($0) }
                    )
                }
                .safeAreaPadding(.vertical, DefaultConstant.defaultContentTopMargins)
                .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            }
            .navigation(naviTitle: .signUp, displayMode: .large)
            .navigationSubtitle(Constants.naviSubtitle)
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
        }
        .task {
            await viewModel.fetchSchools()
            await viewModel.fetchTerms()
        }
        .onChange(of: viewModel.registerState) { _, newState in
            handleRegisterStateChange(newState)
        }
        .alertPrompt(item: $alertPrompt)
    }

    // MARK: - Subviews

    private var submitButton: some View {
        Button {
            Task { await viewModel.register() }
        } label: {
            Group {
                if viewModel.registerState.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(Constants.submitTitle)
                        .appFont(.subheadline, weight: .semibold, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultConstant.defaultBtnPadding)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo500)
        .disabled(!viewModel.isFormValid || viewModel.registerState.isLoading)
        .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Function

    /// 가입 완료 처리 (Q2): 세션 확립 여부와 무관하게 항상 로그인 화면으로 안내한다.
    ///
    /// 소셜 신규가입 회원은 이 시점에 기수(세대)가 배정되지 않았으므로 `showMain()`으로
    /// 분기하지 않는다. `pendingApproval` 전용 상태는 아직 `AppFlow`에 없으므로 선점하지
    /// 않고, 안내 얼럿의 확인 버튼에서 `showLogin()`을 호출한다.
    // TODO(#945): pendingApproval 전용 AppFlow 상태가 추가되면 그쪽으로 분기.
    private func handleRegisterStateChange(_ newState: Loadable<String>) {
        guard case .loaded = newState else { return }
        alertPrompt = AlertPrompt(
            title: Constants.completedTitle,
            message: viewModel.requiresManualLoginAfterRegister
                ? Constants.manualLoginMessage
                : Constants.pendingApprovalMessage,
            positiveBtnTitle: Constants.confirmTitle,
            positiveBtnAction: { appFlow.showLogin() }
        )
    }
}
