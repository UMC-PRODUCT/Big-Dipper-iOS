//
//  StubAuthRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import AuthDomain

/// 카카오 로그인 서버 미등록 기간 한정 인증 Repository stub (핵심규칙 #5).
///
/// `hasSession()`이 항상 `true`이므로 부트스트랩(`CheckAuthStatusUseCase`)이 토큰 검사를
/// 통과하고, stub 프로필 조회 → 승인 판정을 거쳐 로그인 화면 없이 홈으로 직행한다.
/// 소셜 로그인은 전부 기존 회원 성공으로 처리한다 (SDK 호출 이전 단계는 각 Manager 소관이라
/// 카카오 버튼 실탭은 여전히 SDK에서 실패할 수 있음 — 이메일 로그인은 SDK 미경유라 동작).
struct StubAuthRepository: AuthRepositoryProtocol {

    func hasSession() async -> Bool {
        true
    }

    func refreshSession() async throws {}

    func logout() async throws {}

    func loginKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        .existingMember
    }

    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        .existingMember
    }

    func loginGoogle(accessToken: String) async throws -> OAuthLoginResult {
        .existingMember
    }

    func loginByEmail(email: String, password: String) async throws -> LoginByIdPwResult {
        LoginByIdPwResult(memberId: StubSessionFixtures.profile.memberId)
    }

    func fetchMyOAuth() async throws -> [MemberOAuth] {
        []
    }

    func addMemberOAuth(oAuthVerificationToken: String) async throws -> [MemberOAuth] {
        []
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {}

    func deleteMemberOAuth(
        memberOAuthId: String,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws {}
}
#endif
