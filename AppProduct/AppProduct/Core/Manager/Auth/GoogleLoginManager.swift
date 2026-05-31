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
/// GoogleSignIn SDK를 사용하여 사용자 인증을 처리하며, 서버 검증용 `idToken`(로그인)과
/// 연동 해제 검증용 `accessToken`(OAuth 해제)을 발급합니다.
///
/// - Important:
///   - `GIDClientID`가 `Info.plist`에 설정되어 있어야 SDK가 자동 구성됩니다.
///   - 서버는 요청 바디의 `accessToken` 필드에 담긴 **idToken**으로 진위를 검증합니다.
///     (카카오의 `accessToken`(OAuth 액세스 토큰)과 의미가 다릅니다.)
///
/// - Usage:
/// ```swift
/// let googleManager = GoogleLoginManager()
///
/// do {
///     let idToken = try await googleManager.login()
///     print("idToken: \(idToken)")
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

        /// idToken을 찾을 수 없음 (서버 검증 불가)
        case idTokenNotFound
    }

    // MARK: - Function

    /// 구글 로그인을 수행하고 서버 검증용 `idToken`을 반환합니다.
    ///
    /// - Returns: GoogleSignIn에서 발급한 idToken
    /// - Throws:
    ///   - `GoogleLoginError.presentationContextNotFound`: 표시할 화면이 없을 때
    ///   - `GoogleLoginError.idTokenNotFound`: idToken이 없을 때
    ///   - 기타 GoogleSignIn SDK 에러
    @MainActor
    func login() async throws -> String {
        let result = try await signIn()
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleLoginError.idTokenNotFound
        }
        return idToken
    }

    /// 연동 해제 검증용 Google `accessToken`을 반환합니다.
    ///
    /// 서버의 `DELETE /api/v1/member-oauth/{id}` 요청에 `googleAccessToken`으로 전달됩니다.
    ///
    /// - Returns: GoogleSignIn에서 발급한 OAuth 액세스 토큰
    /// - Throws: `GoogleLoginError.presentationContextNotFound` 또는 GoogleSignIn SDK 에러
    @MainActor
    func fetchAccessToken() async throws -> String {
        let result = try await signIn()
        return result.user.accessToken.tokenString
    }

    // MARK: - Private Function

    /// GoogleSignIn 로그인을 수행하고 결과를 반환합니다.
    @MainActor
    private func signIn() async throws -> GIDSignInResult {
        guard let presentingViewController = Self.topViewController() else {
            throw GoogleLoginError.presentationContextNotFound
        }
        return try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController
        )
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
