//
//  SocialLoginManagerProtocols.swift
//  CoreNetwork
//
//  Created by euijjang97 on 7/9/26.
//

/// 카카오 소셜 로그인 매니저 인터페이스.
///
/// `LoginViewModel`이 실제 Kakao SDK 대신 테스트 더블을 주입할 수 있도록 하는 최소 계약이다.
public protocol KakaoLoginManaging {
    /// 카카오 로그인을 수행하고 액세스 토큰과 이메일을 반환한다.
    func login() async throws -> (accessToken: String, email: String)
}

extension KakaoLoginManager: KakaoLoginManaging {}

/// Apple 소셜 로그인 매니저 인터페이스.
///
/// `AppleLoginManager`는 delegate 콜백 기반이라 async 함수 대신 콜백 프로퍼티와
/// 트리거 함수로 계약을 표현한다. `LoginViewModel`이 테스트 더블을 주입할 수 있게 한다.
public protocol AppleLoginManaging: AnyObject {
    /// 로그인 인증 완료 시 호출되는 콜백 (authorizationCode, email, fullName)
    var onAuthorizationCompleted: ((String, String?, String?) -> Void)? { get set }

    /// 인증 실패(또는 사용자 취소) 시 호출되는 콜백
    var onAuthorizationFailed: ((Error) -> Void)? { get set }

    /// Apple 로그인을 시작한다.
    func signWithApple()
}

extension AppleLoginManager: AppleLoginManaging {}

/// Google 소셜 로그인 매니저 인터페이스.
///
/// `LoginViewModel`이 실제 GoogleSignIn SDK 대신 테스트 더블을 주입할 수 있도록 하는 최소 계약이다.
@MainActor
public protocol GoogleLoginManaging {
    /// 구글 로그인을 수행하고 서버 전송용 OAuth accessToken과 계정 이메일을 반환한다.
    func login() async throws -> (accessToken: String, email: String?)
}

extension GoogleLoginManager: GoogleLoginManaging {}
