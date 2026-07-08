/// 소셜 로그인 UseCase 인터페이스
public protocol LoginUseCaseProtocol {
    /// 카카오 로그인 실행
    /// - Parameters:
    ///   - accessToken: 카카오 액세스 토큰
    ///   - email: 사용자 이메일
    /// - Returns: 로그인 결과 (기존/신규 회원)
    func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult

    /// Apple 로그인 실행
    /// - Parameters:
    ///   - authorizationCode: Apple 인증 코드
    ///   - email: Apple에서 제공한 이메일(최초 로그인 시)
    ///   - fullName: Apple에서 제공한 이름(최초 로그인 시)
    /// - Returns: 로그인 결과
    func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult

    /// Google 로그인 실행
    /// - Parameter accessToken: GoogleSignIn에서 발급받은 OAuth accessToken
    /// - Returns: 로그인 결과
    func executeGoogle(accessToken: String) async throws -> OAuthLoginResult
}
