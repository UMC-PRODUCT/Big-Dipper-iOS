/// 소셜 회원가입 UseCase 인터페이스
public protocol RegisterUseCaseProtocol {
    /// 소셜 신규 회원가입을 완료한다.
    /// - Parameters:
    ///   - oAuthVerificationToken: 소셜 로그인 신규 회원 판정 시 발급받은 검증 토큰
    ///   - name: 이름
    ///   - nickname: 닉네임
    ///   - emailVerificationToken: 이메일 인증 완료 토큰
    ///   - schoolId: 선택한 학교 식별자
    ///   - profileImageId: 프로필 이미지 식별자(선택)
    ///   - termsAgreements: 약관 동의 목록
    /// - Returns: 가입 결과(세션 확립 여부 포함)
    func execute(
        oAuthVerificationToken: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        profileImageId: String?,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterResult
}
