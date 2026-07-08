import AuthDomain
import CoreNetwork
import Foundation
import UMCFoundation

/// 인증/세션 관련 Repository 구현체
///
/// 세션 존재 확인·강제 갱신은 `NetworkClient`(Core 인프라)를 그대로 재사용하고,
/// 프로필 조회만 `AuthRouter`를 통해 API를 직접 호출한다.
public struct AuthRepository: AuthRepositoryProtocol {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let networkClient: NetworkClient
    private let tokenStore: TokenStore

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        networkClient: NetworkClient,
        tokenStore: TokenStore
    ) {
        self.adapter = adapter
        self.networkClient = networkClient
        self.tokenStore = tokenStore
    }

    // MARK: - Function

    public func hasSession() async -> Bool {
        await networkClient.isLoggedIn()
    }

    public func refreshSession() async throws {
        _ = try await networkClient.forceRefreshToken()
    }

    public func fetchMyProfile() async throws -> Profile {
        let response = try await adapter.request(AuthRouter.getMe)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<MemberMeResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()
            return dto.toDomain()
        } catch let decodingError as DecodingError {
            #if DEBUG
            let rawBody = String(data: response.data, encoding: .utf8) ?? "<invalid utf8>"
            print("[AuthRepository] fetchMyProfile decodingError=\(decodingError)")
            print("[AuthRepository] fetchMyProfile rawBody=\(rawBody)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }

    public func loginKakao(accessToken: String, email: String) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginKakao(
                body: LoginKakaoRequestDTO(accessToken: accessToken, email: email)
            )
        )
    }

    public func loginApple(
        authorizationCode: String,
        email: String?,
        fullName: String?
    ) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginApple(
                body: LoginAppleRequestDTO(
                    authorizationCode: authorizationCode,
                    email: email,
                    fullName: fullName
                )
            )
        )
    }

    public func loginGoogle(accessToken: String) async throws -> OAuthLoginResult {
        try await performOAuthLogin(
            AuthRouter.loginGoogle(
                body: LoginGoogleRequestDTO(accessToken: accessToken)
            )
        )
    }

    // MARK: - Private Function

    /// OAuth 로그인 응답을 디코딩하고, 기존 회원이면 토큰을 저장한 뒤 결과를 반환한다.
    private func performOAuthLogin(_ target: AuthRouter) async throws -> OAuthLoginResult {
        let response = try await adapter.requestWithoutAuth(target)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<OAuthLoginResponseDTO>.self,
                from: response.data
            )
            let dto = try apiResponse.unwrap()

            if let tokenPair = dto.tokenPair {
                try await tokenStore.save(
                    accessToken: tokenPair.accessToken,
                    refreshToken: tokenPair.refreshToken
                )
                return .existingMember
            }
            return .newMember(verificationToken: dto.oAuthVerificationToken ?? "")
        } catch let decodingError as DecodingError {
            #if DEBUG
            // 응답 body에는 accessToken/refreshToken이 포함될 수 있어 raw body는 출력하지
            // 않고, 디코딩 에러 메시지만 남긴다.
            print("[AuthRepository] performOAuthLogin decodingError=\(decodingError)")
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
}
