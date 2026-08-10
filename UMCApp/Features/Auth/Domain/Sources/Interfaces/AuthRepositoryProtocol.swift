//
//  AuthRepositoryProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/8/26.
//

/// 인증/세션 관련 데이터 접근 계층 인터페이스.
///
/// `NetworkClient`/`TokenStore` 같은 Core 인프라 타입을 Domain 레이어에 노출하지 않도록
/// 세션 존재 확인, 강제 갱신을 최소 계약으로 추상화한다.
public protocol AuthRepositoryProtocol {

    /// 저장된 액세스 토큰 존재 여부를 확인한다. (토큰 유효성 자체는 보장하지 않음)
    func hasSession() async -> Bool

    /// 리프레시 토큰으로 세션을 강제 갱신한다.
    func refreshSession() async throws

    /// 로그아웃 처리를 수행한다. (토큰 정리 등 세션 종료 책임을 Repository로 위임)
    func logout() async throws

    /// 카카오 소셜 로그인을 수행한다.
    /// - Parameters:
    ///   - accessToken: 카카오 SDK에서 발급받은 액세스 토큰
    ///   - email: 카카오 계정 이메일
    /// - Returns: 기존 회원/신규 회원 분기 결과
    func loginKakao(accessToken: String, email: String) async throws -> OAuthLoginResult

    /// Apple 소셜 로그인을 수행한다.
    /// - Parameters:
    ///   - authorizationCode: Apple Sign In에서 발급받은 인증 코드
    ///   - email: Apple에서 제공한 이메일(최초 로그인 시에만 제공)
    ///   - fullName: Apple에서 제공한 이름(최초 로그인 시에만 제공)
    /// - Returns: 기존 회원/신규 회원 분기 결과
    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult

    /// Google 소셜 로그인을 수행한다.
    /// - Parameter accessToken: GoogleSignIn에서 발급받은 OAuth accessToken (서버 검증용)
    /// - Returns: 기존 회원/신규 회원 분기 결과
    func loginGoogle(accessToken: String) async throws -> OAuthLoginResult

    /// 이메일(ID/PW) 로그인을 수행한다.
    /// - Parameters:
    ///   - email: 이메일 주소
    ///   - password: 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    /// - Returns: 로그인 결과 (회원 ID). 토큰 저장은 Repository가 처리한다.
    func loginByEmail(email: String, password: String) async throws -> LoginByIdPwResult

    /// 내 OAuth 연동 목록을 조회한다.
    /// - Returns: 연동된 OAuth 목록
    func fetchMyOAuth() async throws -> [MemberOAuth]

    /// OAuth 수단을 추가 연동한다.
    /// - Parameter oAuthVerificationToken: 소셜 로그인으로 발급받은 검증 토큰
    /// - Returns: 연동 완료 후 전체 OAuth 목록
    func addMemberOAuth(oAuthVerificationToken: String) async throws -> [MemberOAuth]

    /// 로그인 상태에서 비밀번호를 변경한다.
    ///
    /// 이메일 인증 토큰으로 재설정하는 `AuthRegistrationRepositoryProtocol.resetPassword`와 달리
    /// 현재 세션의 액세스 토큰으로 본인을 식별하므로 세션 계약인 이쪽에 둔다.
    /// - Parameters:
    ///   - currentPassword: 현재 비밀번호(평문)
    ///   - newPassword: 새로 설정할 평문 비밀번호
    func changePassword(currentPassword: String, newPassword: String) async throws

    /// OAuth 수단 연동을 해제한다.
    /// - Parameters:
    ///   - memberOAuthId: 해제할 OAuth 연동 ID
    ///   - googleAccessToken: Google 해제 검증용 액세스 토큰
    ///   - kakaoAccessToken: Kakao 해제 검증용 액세스 토큰
    func deleteMemberOAuth(
        memberOAuthId: String,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws
}
