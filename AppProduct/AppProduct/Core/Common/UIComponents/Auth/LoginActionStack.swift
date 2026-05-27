//
//  LoginActionStack.swift
//  AppProduct
//
//  Created by euijjang97 on 5/27/26.
//
//  로그인 액션(카카오/Apple/ID·PW + 고객센터) 영역.
//
//  AuthBootstrapView(시네마틱 종료 후 morph 등장) 와 LoginView(logout 후 fallback) 양쪽에서
//  동일한 시각·동일한 layout 을 갖도록 컴포넌트로 추출한다. 비즈니스 로직은 모두 closure 로
//  외부에서 주입받는 dumb 컴포넌트.
//
//  ## 사용
//
//  ```swift
//  LoginActionStack(
//      isLoading: viewModel.loginState.isLoading,
//      onKakaoTap: { Task { await viewModel.loginWithKakao() } },
//      onAppleTap: { viewModel.loginWithApple() },
//      onSupportTap: { kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler) }
//  )
//  ```
//
//  > Note: 내부의 ID·PW 진입은 `NavigationLink(value:)` 를 사용하므로, 호출부가 `NavigationStack`
//  > 컨텍스트 안에 있고 `NavigationDestination.auth(.loginByIdPw)` 를 처리하는 `navigationDestination`
//  > modifier 를 등록해야 한다.
//

import SwiftUI

/// 로그인 액션 영역 — 카카오/Apple 소셜 버튼 + ID·PW 진입 + 고객센터 푸터.
///
/// 콜백 기반 dumb 컴포넌트라 여러 화면에서 재사용 가능. ID·PW 진입만 `NavigationLink` 라
/// 호출부 `NavigationStack` 에 의존한다.
struct LoginActionStack: View {

    // MARK: - Property

    let isLoading: Bool
    let onKakaoTap: () -> Void
    let onAppleTap: () -> Void
    let onSupportTap: () -> Void

    private enum Constants {
        static let supportInquiryPrompt: String = "로그인에 문제가 있으신가요?"
        static let supportChannelLabel: String = "고객센터"
        static let supportChannelSuffix: String = "로 문의해 주세요."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing32) {
            socialLoginSection
            Divider()
            idPwLoginSection
        }
    }

    // MARK: - Subviews

    private var socialLoginSection: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            kakaoLoginButton
            appleLoginButton
        }
    }

    private var idPwLoginSection: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            idPwLoginButton
            supportFooter
        }
    }

    private var kakaoLoginButton: some View {
        Button(action: onKakaoTap) {
            SocialLoginLabel(.kakao)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text("카카오로 시작하기"))
        .accessibilityHint(Text("카카오 계정으로 로그인합니다"))
    }

    private var appleLoginButton: some View {
        Button(action: onAppleTap) {
            SocialLoginLabel(.apple)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text("Apple로 시작하기"))
        .accessibilityHint(Text("Apple 계정으로 로그인합니다"))
    }

    private var idPwLoginButton: some View {
        NavigationLink(value: NavigationDestination.auth(.loginByIdPw)) {
            SocialLoginLabel(.email)
        }
        .buttonBorderShape(.capsule)
        .disabled(isLoading)
        .accessibilityHint(Text("아이디와 비밀번호 입력 화면으로 이동합니다"))
        .overlay {
            Capsule()
                .fill(.clear)
                .strokeBorder(Color.grey500, style: .init(lineWidth: 0.5))
        }
    }

    private var supportFooter: some View {
        VStack(spacing: DefaultSpacing.spacing4) {
            Text(Constants.supportInquiryPrompt)
                .appFont(.footnote, color: .grey500)
            HStack(spacing: .zero) {
                Button(action: onSupportTap) {
                    Text(Constants.supportChannelLabel)
                        .foregroundStyle(.indigo)
                        .appFont(.footnote, color: .grey500)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("고객센터로 문의하기"))
                .accessibilityHint(Text("카카오톡 UMC 문의 채널을 엽니다"))

                Text(Constants.supportChannelSuffix)
                    .appFont(.footnote, color: .grey500)
            }
        }
        .multilineTextAlignment(.center)
    }
}

#if DEBUG
#Preview("LoginActionStack") {
    NavigationStack {
        LoginActionStack(
            isLoading: false,
            onKakaoTap: {},
            onAppleTap: {},
            onSupportTap: {}
        )
        .padding()
    }
}
#endif
