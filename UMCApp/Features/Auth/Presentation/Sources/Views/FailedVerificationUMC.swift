import CoreDesignSystem
import CoreDI
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 승인 대기(#945) 화면 — 미승인 회원에게 표시되는 UMC 챌린저 인증 대기 안내 화면.
///
/// 회원가입 완료 후 운영진 승인 전이거나, 로그인 시 아직 기수가 배정되지 않은 회원에게
/// 표시된다. 기존 챌린저 코드 재인증, 홈페이지 이동, 문의하기, 로그아웃/회원 탈퇴 외의
/// 다른 화면 진입은 허용하지 않는다.
public struct FailedVerificationUMC: View {

    // MARK: - Property

    @State private var viewModel: FailedVerificationUMCViewModel
    @State private var isBouncing = false
    @Environment(\.openURL) private var openURL
    @Environment(\.appFlow) private var appFlow
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Constant

    fileprivate enum Constants {
        static let topSpacerHeight: CGFloat = 80
        static let contentSpacing: CGFloat = 40
        static let verifyButtonTopPadding: CGFloat = 16
        static let warningIconSize: CGFloat = 120
        static let warningIcon: String = "exclamationmark.triangle"

        static let title: String = "UMC 챌린저 인증 실패"
        static let subtitle: String = "죄송합니다. 입력하신 정보로 등록된 \nUMC 챌린저 정보를 찾을 수 없습니다."
        static let verifyTextButtonTitle: String = "UMC 챌린저 인증하기"

        static let codeAlertTitle: String = "기존 챌린저 코드 입력"
        static let codeTextFieldPlaceholder: String = "6자리 코드"
        static let codeAlertMessage: String = "운영진에게 발급받은 6자리 코드를 입력해주세요."
        static let closeButtonTitle: String = "닫기"
        static let submitButtonTitle: String = "전송"

        static let homePageURL: String = "https://umc.it.kr"
        /// UMC 동아리 카카오톡 채널 ID (카카오톡 채널 관리자 페이지에서 확인 가능).
        static let kakaoChannelWebChatURL: String = "https://pf.kakao.com/_MDxhqX/chat"
        static let inquiryChannelFailureMessage: String =
            "카카오톡 문의 채널을 열 수 없습니다. 잠시 후 다시 시도해주세요."
    }

    // MARK: - Init

    public init(container: DIContainer, errorHandler: ErrorHandler) {
        _viewModel = State(
            initialValue: FailedVerificationUMCViewModel(
                container: container,
                errorHandler: errorHandler
            )
        )
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack {
                Spacer().frame(maxHeight: Constants.topSpacerHeight)
                topWarningImage
                Spacer().frame(maxHeight: Constants.contentSpacing)
                warningTitle
                existingChallengerTextButton
                Spacer()
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .toolbar {
                bottomToolbar
            }
            .alert(
                Constants.codeAlertTitle,
                isPresented: $viewModel.showCodeAlert,
                actions: codeAlertActions,
                message: codeAlertMessage
            )
            .alertPrompt(item: $viewModel.alertPrompt)
        }
        .onChange(of: viewModel.destination) { _, newDestination in
            handle(destination: newDestination)
        }
    }

    // MARK: - Subviews

    private var topWarningImage: some View {
        Image(systemName: Constants.warningIcon)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: Constants.warningIconSize, height: Constants.warningIconSize)
            .foregroundStyle(.red)
            .symbolEffect(.pulse, isActive: viewModel.showWarning)
            .task {
                viewModel.showWarning.toggle()
            }
    }

    private var warningTitle: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            Text(Constants.title)
                .appFont(.title1, weight: .semibold, color: .grey900)

            Text(Constants.subtitle)
                .appFont(.callout, weight: .medium, color: .grey600)
                .multilineTextAlignment(.center)
        }
    }

    private var existingChallengerTextButton: some View {
        Button {
            viewModel.presentCodeAlert()
        } label: {
            Text(Constants.verifyTextButtonTitle)
                .appFont(.callout, weight: .semibold, color: .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .scaleEffect(isBouncing ? 1.08 : 1.0)
        .animation(
            .spring(duration: 0.4, bounce: 0.6)
                .repeatCount(3, autoreverses: true),
            value: isBouncing
        )
        .padding(.top, Constants.verifyButtonTopPadding)
        .disabled(isInteractionDisabled)
        .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isBouncing = true
            }
        }
    }

    private var bottomToolbar: some ToolbarContent {
        ToolBarCollection.FailedVerificationBottomToolbar(
            isSubmitting: viewModel.isSubmitting,
            isDeletingAccount: viewModel.isDeletingAccount,
            isLoggingOut: viewModel.isLoggingOut,
            onHome: openHomePage,
            onInquiry: openInquiryChannel,
            onLogout: viewModel.presentLogoutPrompt,
            onDeleteAccount: viewModel.presentDeleteAccountPrompt
        )
    }

    @ViewBuilder
    private func codeAlertActions() -> some View {
        TextField(
            Constants.codeTextFieldPlaceholder,
            text: $viewModel.challengerCode
        )
        .keyboardType(.asciiCapable)

        Button(Constants.closeButtonTitle, role: .cancel, action: viewModel.dismissCodeAlert)
        Button(Constants.submitButtonTitle, action: submitChallengerCode)
    }

    @ViewBuilder
    private func codeAlertMessage() -> some View {
        Text(Constants.codeAlertMessage)
    }

    // MARK: - Function

    private var isInteractionDisabled: Bool {
        viewModel.isSubmitting ||
        viewModel.isDeletingAccount ||
        viewModel.isLoggingOut
    }

    private func openHomePage() {
        guard let url = URL(string: Constants.homePageURL) else { return }
        openURL(url)
    }

    /// 카카오톡 문의 채널을 연다.
    ///
    /// - Note: 레거시 `KakaoPlusManager`는 `KakaoSDKTalk`에 의존해 카카오톡 설치 시
    ///   인앱 채팅방으로 바로 전환한다. `CoreFoundation`에 KakaoSDK를 끌어들이지 않기
    ///   위해 아직 이식하지 않았고, 대신 웹 채팅 URL을 직접 연다.
    // TODO(#958): KakaoSDKTalk 기반 인앱 채널 연결(KakaoPlusManager) 이식.
    private func openInquiryChannel() {
        guard let url = URL(string: Constants.kakaoChannelWebChatURL) else {
            errorHandler.handle(
                DomainError.custom(message: Constants.inquiryChannelFailureMessage),
                context: ErrorContext(feature: "Auth", action: "openInquiryChannel")
            )
            return
        }
        openURL(url)
    }

    private func submitChallengerCode() {
        Task {
            await viewModel.submitChallengerCode()
        }
    }

    private func handle(destination: FailedVerificationDestination?) {
        switch destination {
        case .login:
            appFlow.showLogin()
        case .main:
            appFlow.showMain()
        case nil:
            break
        }
    }
}
