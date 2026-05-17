//
//  MockAuthRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

/// Auth Repository Mock 구현체
///
/// 개발/테스트 환경에서 서버 없이 동작합니다.
final class MockAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {

    // MARK: - Function

    func loginKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult {
        try await Task.sleep(for: .milliseconds(500))

        return .existingMember(
            tokenPair: TokenPair(
                accessToken: "mock_access_token",
                refreshToken: "mock_refresh_token"
            )
        )
    }

    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        try await Task.sleep(for: .milliseconds(500))

        // Apple 로그인은 서버 미구현 → 에러 반환
        throw RepositoryError.serverError(
            code: "501",
            message: "Apple 로그인은 아직 지원되지 않습니다."
        )
    }

    func loginByEmail(
        _ body: EmailLoginRequestDTO
    ) async throws -> LoginByIdPwResult {
        try await Task.sleep(for: .milliseconds(500))

        guard body.email == "reviewer@umc.dev" && body.password == "umc12345!" else {
            throw RepositoryError.serverError(
                code: "AUTHENTICATION-0022",
                message: "이메일 또는 비밀번호가 올바르지 않습니다."
            )
        }

        return LoginByIdPwResult(
            memberId: "999",
            tokenPair: TokenPair(
                accessToken: "mock_email_access_token",
                refreshToken: "mock_email_refresh_token"
            )
        )
    }

    func registerByEmail(
        _ body: EmailRegisterRequestDTO
    ) async throws -> RegisterByIdPwResult {
        try await Task.sleep(for: .milliseconds(500))

        return RegisterByIdPwResult(
            memberId: "999",
            tokenPair: TokenPair(
                accessToken: "mock_email_access_token",
                refreshToken: "mock_email_refresh_token"
            )
        )
    }

    func checkEmailAvailability(
        email: String
    ) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(300))
        let reservedEmails: Set<String> = [
            "reviewer@umc.dev",
            "admin@umc.dev",
            "test@umc.dev"
        ]
        return !reservedEmails.contains(email.lowercased())
    }

    func renewToken(
        refreshToken: String
    ) async throws -> TokenPair {
        try await Task.sleep(for: .milliseconds(300))

        return TokenPair(
            accessToken: "mock_new_access_token",
            refreshToken: "mock_new_refresh_token"
        )
    }

    func getMyOAuth() async throws -> [MemberOAuth] {
        try await Task.sleep(for: .milliseconds(300))

        return [
            MemberOAuth(
                memberOAuthId: 1,
                memberId: "102",
                provider: .kakao
            )
        ]
    }

    func addMemberOAuth(
        oAuthVerificationToken: String
    ) async throws -> [MemberOAuth] {
        try await Task.sleep(for: .milliseconds(300))

        return [
            MemberOAuth(
                memberOAuthId: 1,
                memberId: "102",
                provider: .kakao
            ),
            MemberOAuth(
                memberOAuthId: 2,
                memberId: "102",
                provider: .apple
            )
        ]
    }

    func deleteMemberOAuth(
        memberOAuthId: Int,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func sendEmailVerification(
        email: String
    ) async throws -> String {
        try await Task.sleep(for: .milliseconds(500))
        return "mock_verification_id_1"
    }

    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String {
        try await Task.sleep(for: .milliseconds(500))
        return "mock_email_verification_token"
    }

    func register(
        request: RegisterRequestDTO
    ) async throws -> String {
        try await Task.sleep(for: .milliseconds(500))
        return "1"
    }

    func registerExistingChallenger(
        code: String
    ) async throws {
        try await Task.sleep(for: .milliseconds(300))
        guard code == "123456" else {
            throw RepositoryError.serverError(
                code: "CHALLENGER_CODE_NOT_FOUND",
                message: "입력 코드 번호가 존재하지 않습니다."
            )
        }
    }

    func getSchools() async throws -> [School] {
        try await Task.sleep(for: .milliseconds(300))
        return [
            School(id: "1", name: "중앙대학교"),
            School(id: "2", name: "서울대학교"),
            School(id: "3", name: "연세대학교")
        ]
    }

    func registerCredential(rawPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func getTerms(
        termsType: String
    ) async throws -> Terms {
        try await Task.sleep(for: .milliseconds(300))
        let type = TermsType(rawValue: termsType) ?? .service
        return Terms(
            id: type == .service ? "2" : "1",
            link: "https://example.com/terms/\(type.rawValue.lowercased())",
            isMandatory: true,
            termsType: type
        )
    }
}
