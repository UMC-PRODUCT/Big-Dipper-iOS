//
//  LoginActionStack.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import SwiftUI

/// 로그인 액션 영역 — 카카오/Apple/Google 소셜 버튼.
///
/// 콜백 기반 dumb 컴포넌트라 여러 화면에서 재사용 가능하다.
///
/// - Note: ID·PW 로그인, 고객센터 문의 버튼은 이 컴포넌트의 스코프에 포함되지 않는다
///   (이메일 로그인 `#943`, 카카오플러스 채널 연동은 별도 매니저 — 이 화면의 스코프 밖).
public struct LoginActionStack: View {

    // MARK: - Property

    private let isLoading: Bool
    private let onKakaoTap: () -> Void
    private let onAppleTap: () -> Void
    private let onGoogleTap: () -> Void

    // MARK: - Init

    public init(
        isLoading: Bool,
        onKakaoTap: @escaping () -> Void,
        onAppleTap: @escaping () -> Void,
        onGoogleTap: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.onKakaoTap = onKakaoTap
        self.onAppleTap = onAppleTap
        self.onGoogleTap = onGoogleTap
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            kakaoLoginButton
            appleLoginButton
            googleLoginButton
        }
    }

    // MARK: - Subviews

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
}

#if DEBUG
#Preview("LoginActionStack") {
    LoginActionStack(
        isLoading: false,
        onKakaoTap: {},
        onAppleTap: {},
        onGoogleTap: {}
    )
    .padding()
}
#endif
