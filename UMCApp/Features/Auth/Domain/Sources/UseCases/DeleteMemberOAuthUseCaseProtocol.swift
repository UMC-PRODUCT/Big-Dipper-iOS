/// 로그인 OAuth 수단 연동 해제 UseCase 인터페이스
public protocol DeleteMemberOAuthUseCaseProtocol {
    /// OAuth 연동을 해제한다.
    /// - Parameters:
    ///   - memberOAuthId: 해제할 OAuth 연동 ID
    ///   - googleAccessToken: Google 연동 해제 검증용 액세스 토큰
    ///   - kakaoAccessToken: Kakao 연동 해제 검증용 액세스 토큰
    func execute(
        memberOAuthId: String,
        googleAccessToken: String?,
        kakaoAccessToken: String?
    ) async throws
}
