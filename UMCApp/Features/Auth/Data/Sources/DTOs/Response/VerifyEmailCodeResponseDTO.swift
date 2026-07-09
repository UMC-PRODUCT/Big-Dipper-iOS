/// 이메일 인증 코드 검증 API 응답 DTO
public struct VerifyEmailCodeResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 이메일 인증 토큰 (회원가입 시 사용)
    public let emailVerificationToken: String

    private enum CodingKeys: String, CodingKey {
        case emailVerificationToken
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emailVerificationToken = try container.decodeIfPresent(
            String.self,
            forKey: .emailVerificationToken
        ) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emailVerificationToken, forKey: .emailVerificationToken)
    }
}
