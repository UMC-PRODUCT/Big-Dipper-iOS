//
//  LoginActionStack.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import SwiftUI

/// 로그인 액션 영역 — 카카오/Apple/Google 소셜 버튼 + UMC 계정(ID·PW) 진입 + 고객센터 푸터.
///
/// 콜백 기반 dumb 컴포넌트라 여러 화면에서 재사용 가능하다.
public struct LoginActionStack: View {

    // MARK: - Property

    private let isLoading: Bool
    private let onKakaoTap: () -> Void
    private let onAppleTap: () -> Void
    private let onGoogleTap: () -> Void
    private let onEmailTap: () -> Void
    private let onSupportTap: () -> Void

    private enum Constants {
        static let supportInquiryPrompt: String = "로그인에 문제가 있으신가요?"
        static let supportChannelLabel: String = "고객센터"
        static let supportChannelSuffix: String = "로 문의해 주세요."
    }

    // MARK: - Init

    public init(
        isLoading: Bool,
        onKakaoTap: @escaping () -> Void,
        onAppleTap: @escaping () -> Void,
        onGoogleTap: @escaping () -> Void,
        onEmailTap: @escaping () -> Void,
        onSupportTap: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.onKakaoTap = onKakaoTap
        self.onAppleTap = onAppleTap
        self.onGoogleTap = onGoogleTap
        self.onEmailTap = onEmailTap
        self.onSupportTap = onSupportTap
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: DefaultSpacing.spacing32) {
            socialLoginSection
            Divider()
            VStack(spacing: DefaultSpacing.spacing12) {
                emailLoginButton
                supportFooter
            }
        }
    }

    // MARK: - Subviews

    private var socialLoginSection: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            kakaoLoginButton
            appleLoginButton
            googleLoginButton
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

    private var googleLoginButton: some View {
        Button(action: onGoogleTap) {
            SocialLoginLabel(.google)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text("Google로 시작하기"))
        .accessibilityHint(Text("Google 계정으로 로그인합니다"))
        .overlay {
            Capsule()
                .fill(.clear)
                .strokeBorder(Color.grey500, style: .init(lineWidth: 0.5))
        }
    }

    private var emailLoginButton: some View {
        Button(action: onEmailTap) {
            SocialLoginLabel(.email)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text("UMC 계정으로 로그인"))
        .accessibilityHint(Text("아이디와 비밀번호 입력 화면으로 이동합니다"))
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
    LoginActionStack(
        isLoading: false,
        onKakaoTap: {},
        onAppleTap: {},
        onGoogleTap: {},
        onEmailTap: {},
        onSupportTap: {}
    )
    .padding()
}
#endif
