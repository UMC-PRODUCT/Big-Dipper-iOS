//
//  AuthRepositoryProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

/// Auth 데이터 접근 Repository Protocol
protocol AuthRepositoryProtocol: Sendable {

    /// 카카오 소셜 로그인
    /// - Parameters:
    ///   - accessToken: 카카오 액세스 토큰
    ///   - email: 사용자 이메일
    /// - Returns: 로그인 결과 (기존 회원/신규 회원)
    func loginKakao(
        accessToken: String,
        email: String
    ) async throws -> OAuthLoginResult

    /// Apple 소셜 로그인
    /// - Parameters:
    ///   - authorizationCode: Apple 인증 코드
    ///   - email: Apple에서 제공한 이메일(최초 로그인 시)
    ///   - fullName: Apple에서 제공한 사용자 이름(최초 로그인 시)
    /// - Returns: 로그인 결과
    func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult

    /// 토큰 재발급
    /// - Parameter refreshToken: 리프레시 토큰
    /// - Returns: 새 토큰 쌍
    func renewToken(
        refreshToken: String
    ) async throws -> TokenPair

    /// 내 OAuth 연동 정보 조회
    /// - Returns: OAuth 연동 정보 목록
    func getMyOAuth() async throws -> [MemberOAuth]

    /// 로그인 OAuth 수단 추가 연동
    /// - Parameter oAuthVerificationToken: 소셜 로그인 검증 토큰
    /// - Returns: 연동 완료된 OAuth 목록
    func addMemberOAuth(
        oAuthVerificationToken: String
    ) async throws -> [MemberOAuth]

    /// 로그인 OAuth 수단 연동 해제
    /// - Parameters:
    ///   - memberOAuthId: 해제할 OAuth 연동 ID
    ///   - googleAccessToken: Google 해제 검증용 액세스 토큰
    ///   - kakaoAccessToken: Kakao 해제 검증용 액세스 토큰
    func deleteMemberOAuth(
        memberOAuthId: Int,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws

    /// 이메일 인증 발송
    /// - Parameter email: 인증할 이메일 주소
    /// - Returns: 이메일 인증 ID
    func sendEmailVerification(
        email: String
    ) async throws -> String

    /// 이메일 인증코드 검증
    /// - Parameters:
    ///   - emailVerificationId: 이메일 인증 ID
    ///   - verificationCode: 인증 코드
    /// - Returns: 이메일 인증 토큰
    func verifyEmailCode(
        emailVerificationId: String,
        verificationCode: String
    ) async throws -> String

    /// 회원가입
    /// - Parameter request: 회원가입 요청 DTO
    /// - Returns: 생성된 회원 ID (서버 응답 String 기준)
    func register(
        request: RegisterRequestDTO
    ) async throws -> String

    /// 기존 챌린저 코드 인증
    /// - Parameter code: 운영진 발급 6자리 코드
    func registerExistingChallenger(
        code: String
    ) async throws

    /// 학교 목록 조회
    /// - Returns: 학교 목록
    func getSchools() async throws -> [School]

    /// 약관 조회
    /// - Parameter termsType: 약관 종류 (SERVICE, PRIVACY, MARKETING)
    /// - Returns: 약관 정보
    func getTerms(
        termsType: String
    ) async throws -> Terms
}
