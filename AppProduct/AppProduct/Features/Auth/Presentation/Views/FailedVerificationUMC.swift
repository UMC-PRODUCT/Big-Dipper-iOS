//
//  FaieldVerificationUMC.swift
//  AppProduct
//
//  Created by euijjang97 on 1/13/26.
//

import SwiftUI

/// UMC 챌린저 인증 실패 화면
///
/// 회원가입 시 입력한 정보로 UMC 챌린저를 찾을 수 없을 때 표시되는 뷰입니다.
/// 사용자에게 UMC 공식 홈페이지 방문과 카카오톡 채널 문의 옵션을 제공합니다.
struct FailedVerificationUMC: View {

    // MARK: - Property

    /// 화면 상태와 사용자 액션을 관리하는 ViewModel입니다.
    @State private var viewModel = FailedVerificationUMCViewModel()

    /// URL을 외부 브라우저로 여는 환경 값
    @Environment(\.openURL) private var openURL
    /// 루트 화면 전환을 담당하는 앱 플로우 환경 값입니다.
    @Environment(\.appFlow) private var appFlow
    /// Feature 의존성을 조회하는 DI 컨테이너 환경 값입니다.
    @Environment(\.di) private var di
    /// 전역 에러 처리를 담당하는 핸들러입니다.
    @Environment(ErrorHandler.self) private var errorHandler

    /// 카카오톡 채널 연동 매니저
    private let kakaoPlusManager: KakaoPlusManager = .init()

    // MARK: - Constant

    /// 레이아웃 및 텍스트 상수
    private enum Constants {
        /// 상단 여백 높이
        static let topSpacerHeight: CGFloat = 80

        /// 메인 컴포넌트 간 수직 간격
        static let contentSpacing: CGFloat = 40

        /// 기존 챌린저 인증 버튼 상단 여백입니다.
        static let verifyButtonTopPadding: CGFloat = 16

        /// 경고 아이콘 크기
        static let warningIconSize: CGFloat = 120

        /// 경고 아이콘 SF Symbol 이름
        static let warningIcon: String = "exclamationmark.triangle"

        /// 메인 타이틀 텍스트
        static let title: String = "UMC 챌린저 인증 실패"

        /// 서브타이틀 텍스트
        static let subtitle: String = "죄송합니다. 입력하신 정보로 등록된 \nUMC 챌린저 정보를 찾을 수 없습니다."

        /// 상단 텍스트 버튼용 UMC 챌린저 인증 문구
        static let verifyTextButtonTitle: String = "UMC 챌린저 인증하기"

        /// 기존 챌린저 코드 입력 얼럿 제목
        static let codeAlertTitle: String = "기존 챌린저 코드 입력"

        /// 기존 챌린저 코드 입력 필드 플레이스홀더
        static let codeTextFieldPlaceholder: String = "6자리 코드"

        /// 기존 챌린저 코드 입력 안내 문구
        static let codeAlertMessage: String = "운영진에게 발급받은 6자리 코드를 입력해주세요."

        /// 코드 입력 얼럿 닫기 버튼 문구
        static let closeButtonTitle: String = "닫기"

        /// 코드 입력 얼럿 전송 버튼 문구
        static let submitButtonTitle: String = "전송"

        /// UMC 공식 홈페이지 URL
        static let homePageURL: String = "https://umc.it.kr"
    }

    // MARK: - Body

    /// 인증 실패 안내 화면을 구성합니다.
    ///
    /// 상단 설명 영역, 기존 챌린저 인증 버튼, 하단 툴바 액션과
    /// 코드 입력 얼럿을 함께 조합해 제공합니다.
    var body: some View {
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
    }

    // MARK: - Helper

    /// 상단 경고 아이콘
    ///
    /// 빨간색 삼각 경고 아이콘에 pulse 효과를 적용합니다.
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

    /// 인증 실패 안내 문구
    ///
    /// 메인 타이틀과 서브타이틀로 구성된 텍스트 영역입니다.
    private var warningTitle: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            Text(Constants.title)
                .appFont(.title1Emphasis, color: .grey900)

            Text(Constants.subtitle)
                .appFont(.callout, weight: .medium, color: .grey600)
                .multilineTextAlignment(.center)
        }
    }

    /// 제목/부제목 하단의 UMC 챌린저 인증 텍스트 버튼
    @State private var isBouncing = false

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

    /// 하단 툴바 액션 구성을 제공합니다.
    ///
    /// 하단 계정 버튼은 `confirmationDialog`를 직접 소유한 툴바 컴포넌트에
    /// 액션 클로저만 전달합니다.
    private var bottomToolbar: some ToolbarContent {
        ToolBarCollection.FailedVerificationBottomToolbar(
            isSubmitting: viewModel.isSubmitting,
            isDeletingAccount: viewModel.isDeletingAccount,
            isLoggingOut: viewModel.isLoggingOut,
            onHome: openHomePage,
            onInquiry: openInquiryChannel,
            onLogout: presentLogoutPrompt,
            onDeleteAccount: presentDeleteAccountPrompt
        )
    }

    /// 기존 챌린저 코드 입력 얼럿의 버튼과 입력 필드를 구성합니다.
    @ViewBuilder
    private func codeAlertActions() -> some View {
        TextField(
            Constants.codeTextFieldPlaceholder,
            text: $viewModel.challengerCode
        )
        .keyboardType(.asciiCapable)

        Button(Constants.closeButtonTitle, role: .cancel, action: dismissCodeAlert)
        Button(Constants.submitButtonTitle, action: submitChallengerCode)
    }

    /// 기존 챌린저 코드 입력 얼럿의 안내 문구를 제공합니다.
    @ViewBuilder
    private func codeAlertMessage() -> some View {
        Text(Constants.codeAlertMessage)
    }

    /// 화면 상의 주요 인터랙션을 잠글지 여부를 반환합니다.
    ///
    /// 요청 전송, 로그아웃, 회원 탈퇴 중에는 중복 액션을 막기 위해 `true`를 반환합니다.
    private var isInteractionDisabled: Bool {
        viewModel.isSubmitting ||
        viewModel.isDeletingAccount ||
        viewModel.isLoggingOut
    }

    // MARK: - Private Function

    /// UMC 공식 홈페이지를 외부 브라우저로 엽니다.
    ///
    /// - Important: URL 생성에 실패하면 아무 동작도 하지 않습니다.
    private func openHomePage() {
        guard let url = URL(string: Constants.homePageURL) else { return }
        openURL(url)
    }

    /// 카카오톡 문의 채널을 엽니다.
    private func openInquiryChannel() {
        kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
    }

    /// 승인 대기 화면에서 로그아웃 확인 프롬프트를 표시합니다.
    private func presentLogoutPrompt() {
        viewModel.presentLogoutPrompt(
            container: di,
            appFlow: appFlow,
            errorHandler: errorHandler
        )
    }

    /// 승인 대기 화면에서 회원 탈퇴 확인 프롬프트를 표시합니다.
    private func presentDeleteAccountPrompt() {
        viewModel.presentDeleteAccountPrompt(
            container: di,
            appFlow: appFlow,
            errorHandler: errorHandler
        )
    }

    /// 코드 입력 얼럿을 닫고 입력값을 정리합니다.
    private func dismissCodeAlert() {
        viewModel.dismissCodeAlert()
    }

    /// 입력된 기존 챌린저 코드를 서버로 전송합니다.
    ///
    /// 비동기 인증 요청은 `Task`로 감싸 UI 이벤트 처리 흐름과 분리합니다.
    private func submitChallengerCode() {
        Task {
            await viewModel.submitChallengerCode(
                container: di,
                appFlow: appFlow
            )
        }
    }
}
