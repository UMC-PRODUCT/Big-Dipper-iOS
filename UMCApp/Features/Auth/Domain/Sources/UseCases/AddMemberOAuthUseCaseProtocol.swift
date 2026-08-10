/// 로그인 OAuth 수단 추가 연동 UseCase 인터페이스
public protocol AddMemberOAuthUseCaseProtocol {
    /// OAuth 검증 토큰으로 연동을 추가한다.
    /// - Parameter oAuthVerificationToken: 소셜 로그인 시 발급받은 검증 토큰
    /// - Returns: 연동 완료 후 전체 OAuth 목록
    func execute(oAuthVerificationToken: String) async throws -> [MemberOAuth]
}
