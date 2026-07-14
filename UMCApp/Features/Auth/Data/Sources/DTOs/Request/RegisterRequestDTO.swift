//
//  RegisterRequestDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

/// 소셜 회원가입 API 요청 DTO
///
/// `POST /api/v1/member/register`
public struct RegisterRequestDTO: Encodable {
    /// OAuth 인증 토큰 (소셜 로그인 신규 회원 판정 시 발급)
    public let oAuthVerificationToken: String
    /// 사용자 실명
    public let name: String
    /// 닉네임
    public let nickname: String
    /// 이메일 인증 토큰 (이메일 인증 완료 시 발급)
    public let emailVerificationToken: String
    /// 학교 ID (서버가 String 반환)
    public let schoolId: String
    /// 프로필 이미지 ID (선택)
    public let profileImageId: String?
    /// 약관 동의 목록
    public let termsAgreements: [TermsAgreementDTO]

    public init(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreementDTO]
    ) {
        self.oAuthVerificationToken = oAuthVerificationToken
        self.name = name
        self.nickname = nickname
        self.emailVerificationToken = emailVerificationToken
        self.schoolId = schoolId
        self.profileImageId = profileImageId
        self.termsAgreements = termsAgreements
    }
}
