/// 약관 도메인 모델
public struct Terms: Equatable, Sendable {

    // MARK: - Property

    public let id: String
    public let type: TermsType
    public let link: String
    public let isMandatory: Bool

    // MARK: - Init

    public init(id: String, type: TermsType, link: String, isMandatory: Bool) {
        self.id = id
        self.type = type
        self.link = link
        self.isMandatory = isMandatory
    }
}

/// 약관 종류.
///
/// rawValue는 서버 path param(`GET /api/v1/terms/type/{termsType}`)에 그대로 사용된다.
public enum TermsType: String, Equatable, Sendable, CaseIterable {
    case service = "SERVICE"
    case privacy = "PRIVACY"
    case marketing = "MARKETING"
}
