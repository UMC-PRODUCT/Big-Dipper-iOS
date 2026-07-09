/// 약관 동의 항목 요청 DTO
///
/// 소셜 회원가입(`register`)/이메일 회원가입(`registerByEmail`) 양쪽 요청이 공유한다
/// (레거시의 `TermsAgreementDTO`/`EmailRegisterTermsAgreementDTO` 중복 정의를 통합).
public struct TermsAgreementDTO: Encodable {
    /// 약관 ID (서버 응답 String 기준)
    public let termsId: String
    /// 동의 여부
    public let isAgreed: Bool

    public init(termsId: String, isAgreed: Bool) {
        self.termsId = termsId
        self.isAgreed = isAgreed
    }
}
