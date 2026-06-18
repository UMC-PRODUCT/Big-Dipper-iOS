//
//  GoogleLoginManager.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import Foundation
import GoogleSignIn
import UIKit

/// 구글 로그인을 처리하는 매니저입니다.
///
/// GoogleSignIn SDK를 사용하여 사용자 인증을 처리하고, 서버 전송용 OAuth `accessToken`을 발급합니다.
/// (로그인·연동 해제 모두 이 accessToken을 사용합니다.)
///
/// - Important:
///   - `GIDClientID`가 `Info.plist`에 설정되어 있어야 SDK가 자동 구성됩니다.
///   - 서버는 요청 바디의 `accessToken` 필드에 담긴 **구글 OAuth accessToken**으로 진위를 검증합니다.
///     (카카오와 동일하게 provider의 OAuth accessToken을 전달합니다.)
///
/// - Usage:
/// ```swift
/// let googleManager = GoogleLoginManager()
///
/// do {
///     let accessToken = try await googleManager.fetchAccessToken()
///     print("accessToken: \(accessToken)")
/// } catch {
///     print("로그인 실패: \(error)")
/// }
/// ```
final class GoogleLoginManager {
    // MARK: - Nested Types

    /// 구글 로그인 관련 에러를 정의하는 열거형입니다.
    enum GoogleLoginError: Error {
        /// 로그인 UI를 띄울 화면(presentation context)을 찾을 수 없음
        case presentationContextNotFound
    }

    // MARK: - Function

    /// 서버 전송용 Google OAuth `accessToken`을 반환합니다.
    ///
    /// 로그인(`POST /api/v1/auth/login/google`)과 연동 해제(`DELETE /api/v1/member-oauth/{id}`)
    /// 요청에 모두 이 토큰을 전달합니다.
    ///
    /// - Returns: GoogleSignIn에서 발급한 OAuth 액세스 토큰
    /// - Throws: `GoogleLoginError.presentationContextNotFound` 또는 GoogleSignIn SDK 에러
    @MainActor
    func fetchAccessToken() async throws -> String {
        let result = try await signIn()
        return result.user.accessToken.tokenString
    }

    /// 구글 로그인을 수행하고 서버 전송용 OAuth `accessToken`과 계정 이메일을 함께 반환합니다.
    ///
    /// 이메일은 신규 회원가입 진입 시 인증 필드 프리필에 사용합니다.
    ///
    /// - Returns: (OAuth accessToken, 계정 이메일) 튜플. 이메일은 프로필 스코프 미동의 등으로
    ///   제공되지 않을 수 있어 옵셔널입니다.
    /// - Throws: `GoogleLoginError.presentationContextNotFound` 또는 GoogleSignIn SDK 에러
    @MainActor
    func login() async throws -> (accessToken: String, email: String?) {
        let result = try await signIn()
        return (
            result.user.accessToken.tokenString,
            result.user.profile?.email
        )
    }

    // MARK: - Private Function

    /// GoogleSignIn 로그인을 수행하고 결과를 반환합니다.
    @MainActor
    private func signIn() async throws -> GIDSignInResult {
        guard let presentingViewController = Self.topViewController() else {
            throw GoogleLoginError.presentationContextNotFound
        }
        do {
            return try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            // 사용자가 로그인 시트를 취소(X)한 경우 — 에러가 아니므로 정규화합니다.
            throw SocialLoginError.cancelled
        }
    }

    /// 현재 화면에서 가장 위에 표시된 ViewController를 반환합니다.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
