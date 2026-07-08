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

    // MARK: - Init

    public init(adapter: MoyaNetworkAdapter, networkClient: NetworkClient) {
        self.adapter = adapter
        self.networkClient = networkClient
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
            let apiResponse = try JSONDecoder().decode(APIResponse<MemberMeResponseDTO>.self, from: response.data)
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
}
