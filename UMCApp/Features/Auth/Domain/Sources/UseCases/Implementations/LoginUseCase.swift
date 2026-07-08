/// 소셜 로그인 UseCase 구현체
///
/// 토큰 저장은 Repository(Data 레이어)가 내부적으로 처리하므로, 이 UseCase는
/// Repository 결과를 그대로 전달하는 얇은 통과(pass-through) 계층이다.
public final class LoginUseCase: LoginUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol

    // MARK: - Init

    public init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func executeKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        try await repository.loginKakao(accessToken: accessToken, email: email)
    }

    public func executeApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        try await repository.loginApple(
            authorizationCode: authorizationCode,
            email: email,
            fullName: fullName
        )
    }

    public func executeGoogle(accessToken: String) async throws -> OAuthLoginResult {
        try await repository.loginGoogle(accessToken: accessToken)
    }
}
