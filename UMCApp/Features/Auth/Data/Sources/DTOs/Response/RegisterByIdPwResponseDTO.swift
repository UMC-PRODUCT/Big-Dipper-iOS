import UMCFoundation

/// 이메일(ID/PW) 회원가입 API 응답 DTO
///
/// 이메일 가입은 서버가 가입과 동시에 항상 토큰을 발급하므로 `accessToken`/`refreshToken`이
/// 필수 필드다. 레거시(`RegisterByIdPwResponseDTO`)는 synthesized `Codable`이었으나,
/// `memberId`의 flexible String 디코딩을 위해 custom `init(from:)`으로 재작성한다(절대 규칙 #3).
public struct RegisterByIdPwResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 생성된 회원 ID (서버가 String 반환, Int로 흔들릴 수 있어 flexible 디코딩)
    public let memberId: String
    /// JWT 액세스 토큰
    public let accessToken: String
    /// JWT 리프레시 토큰
    public let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case memberId
        case accessToken
        case refreshToken
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
    }
}
