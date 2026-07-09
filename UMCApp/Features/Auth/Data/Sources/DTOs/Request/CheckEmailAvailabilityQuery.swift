/// 이메일 중복 검사 Query DTO
///
/// `GET /api/v1/auth/email/availability?email=...`
public struct CheckEmailAvailabilityQuery: Encodable {
    /// 검사 대상 이메일 주소
    public let email: String

    public init(email: String) {
        self.email = email
    }

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        ["email": email]
    }
}
