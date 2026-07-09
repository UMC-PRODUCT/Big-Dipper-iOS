/// 이메일(ID/PW) 회원가입 API 요청 DTO
///
/// `POST /api/v1/member/register/email`
public struct EmailRegisterRequestDTO: Encodable {
    /// 평문 비밀번호
    public let rawPassword: String
    /// 사용자 실명
    public let name: String
    /// 닉네임
    public let nickname: String
    /// 이메일 인증 토큰 (이메일 인증 완료 시 발급, 이메일 식별자 내장)
    public let emailVerificationToken: String
    /// 학교 ID (서버가 String 반환)
    public let schoolId: String
    /// 약관 동의 목록
    public let termsAgreements: [TermsAgreementDTO]

    public init(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreementDTO]
    ) {
        self.rawPassword = rawPassword
        self.name = name
        self.nickname = nickname
        self.emailVerificationToken = emailVerificationToken
        self.schoolId = schoolId
        self.termsAgreements = termsAgreements
    }
}
