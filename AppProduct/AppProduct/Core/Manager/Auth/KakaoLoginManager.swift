//
//  KakaoLoginManager.swift
//  AppProduct
//
//  Created by euijjang97 on 1/11/26.
//

import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// 카카오 로그인을 처리하는 매니저입니다.
///
/// 카카오톡 앱 로그인과 카카오 계정 로그인을 지원하며, 액세스 토큰과 사용자 이메일을 가져옵니다.
///
/// - Important:
///   - 카카오톡 앱이 설치되어 있으면 카카오톡으로 로그인 (더 빠르고 편리)
///   - 카카오톡 앱이 없으면 카카오 계정으로 로그인 (웹뷰 방식)
///
/// - Usage:
/// ```swift
/// let kakaoManager = KakaoLoginManager()
///
/// do {
///     let (accessToken, email) = try await kakaoManager.login()
///     print("Access Token: \(accessToken)")
///     print("Email: \(email)")
/// } catch {
///     print("로그인 실패: \(error)")
/// }
/// ```
class KakaoLoginManager {
    // MARK: - Nested Types

    /// 카카오 로그인 관련 에러를 정의하는 열거형입니다.
    enum KakaoLoginError: Error {
        /// 액세스 토큰을 찾을 수 없음
        case tokenNotFound

        /// 사용자 정보를 찾을 수 없음
        case userInfoNotFound

        /// 이메일 정보를 찾을 수 없음 (카카오 계정에 이메일 미등록)
        case emailNotFound

        /// 닉네임 정보를 찾을 수 없음
        case nicknameNotFound
    }

    // MARK: - Function

    /// 카카오 액세스 토큰을 가져옵니다.
    ///
    /// 카카오톡 앱이 설치되어 있으면 카카오톡으로 로그인하고,
    /// 없으면 카카오 계정(웹뷰)으로 로그인합니다.
    ///
    /// - Returns: 카카오 액세스 토큰
    /// - Throws:
    ///   - `KakaoLoginError.tokenNotFound`: 토큰을 찾을 수 없을 때
    ///   - 기타 Kakao SDK 에러
    func fetchAccessToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            if UserApi.isKakaoTalkLoginAvailable() {
                // 카카오톡 앱으로 로그인
                UserApi.shared.loginWithKakaoTalk { oauthToken, error in
                    if let error = error {
                        continuation.resume(throwing: Self.normalizedLoginError(error))
                    } else if let oauthToken = oauthToken {
                        continuation.resume(returning: oauthToken.accessToken)
                    } else {
                        continuation.resume(throwing: KakaoLoginError.tokenNotFound)
                    }
                }
            } else {
                // 카카오 계정(웹뷰)으로 로그인
                UserApi.shared.loginWithKakaoAccount { oauthToken, error in
                    if let error = error {
                        continuation.resume(throwing: Self.normalizedLoginError(error))
                    } else if let oauthToken = oauthToken {
                        continuation.resume(returning: oauthToken.accessToken)
                    } else {
                        continuation.resume(throwing: KakaoLoginError.tokenNotFound)
                    }
                }
            }
        }
    }

    /// 카카오 SDK의 사용자 취소 에러를 공통 `SocialLoginError.cancelled`로 정규화합니다.
    ///
    /// 취소(X)는 정상적인 사용자 행동이므로 상위 레이어에서 에러 알럿을 띄우지 않게 합니다.
    private static func normalizedLoginError(_ error: Error) -> Error {
        if let sdkError = error as? SdkError,
           case .ClientFailed(reason: .Cancelled, errorMessage: _) = sdkError {
            return SocialLoginError.cancelled
        }
        return error
    }

    /// 카카오 사용자의 이메일을 가져옵니다.
    ///
    /// - Returns: 사용자 이메일
    /// - Throws:
    ///   - `KakaoLoginError.emailNotFound`: 이메일 정보를 찾을 수 없을 때
    ///   - 기타 Kakao SDK 에러
    ///
    /// - Note: 카카오 계정에 이메일이 등록되어 있어야 합니다.
    func getUserEmail() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.me { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let email = user?.kakaoAccount?.email {
                    continuation.resume(returning: email)
                } else {
                    continuation.resume(throwing: KakaoLoginError.emailNotFound)
                }
            }
        }
    }

    /// 카카오 로그인을 수행하고 액세스 토큰과 이메일을 반환합니다.
    ///
    /// 액세스 토큰과 이메일을 병렬로 가져와 성능을 최적화합니다.
    ///
    /// - Returns: (액세스 토큰, 이메일) 튜플
    /// - Throws: `fetchAccessToken()` 또는 `getUserEmail()`에서 발생한 에러
    ///
    /// - Important: 서버로 전송할 때는 액세스 토큰을 사용합니다.
    func login() async throws -> (accessToken: String, email: String) {
        let accessToken = try await fetchAccessToken()

        async let email = getUserEmail()

        return try await (accessToken, email)
    }
}
