import UMCFoundation

/// 소셜 회원가입 API 응답 DTO
///
/// 서버가 회원가입 응답에 토큰을 함께 내려주면(`accessToken`/`refreshToken`) 별도 재로그인
/// 없이 그대로 세션을 복구할 수 있다. 토큰 필드는 서버 스펙에 따라 없을 수 있으므로
/// 옵셔널로 디코딩하고, 없으면 Repository가 소셜 재로그인 폴백으로 처리한다.
public struct RegisterResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 생성된 회원 ID (서버가 String 반환, Int로 흔들릴 수 있어 flexible 디코딩)
    public let memberId: String
    /// JWT 액세스 토큰 (서버가 가입 응답에 포함할 경우)
    public let accessToken: String?
    /// JWT 리프레시 토큰 (서버가 가입 응답에 포함할 경우)
    public let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case memberId
        case accessToken
        case refreshToken
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
    }
}
