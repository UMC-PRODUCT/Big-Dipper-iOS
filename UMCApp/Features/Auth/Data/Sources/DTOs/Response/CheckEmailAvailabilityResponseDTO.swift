import UMCFoundation

/// 이메일 중복 검사 API 응답 DTO
///
/// `GET /api/v1/auth/email/availability`
///
/// 레거시(`CheckEmailAvailabilityResponseDTO`)는 synthesized `Codable`이었으나,
/// `available`의 flexible Bool 디코딩을 위해 custom `init(from:)`으로 재작성한다(절대 규칙 #3).
public struct CheckEmailAvailabilityResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 검사 대상 이메일 (서버가 정규화하여 반환)
    public let email: String
    /// 사용 가능 여부 (true: 사용 가능, false: 이미 사용 중)
    public let available: Bool

    private enum CodingKeys: String, CodingKey {
        case email
        case available
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        available = try container.decodeBoolFlexibleIfPresent(forKey: .available) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(available, forKey: .available)
    }
}
