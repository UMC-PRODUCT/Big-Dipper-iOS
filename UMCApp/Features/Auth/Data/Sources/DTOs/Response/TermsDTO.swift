import AuthDomain
import UMCFoundation

/// 약관 조회 API 응답 DTO
public struct TermsDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 약관 ID (termsId로 사용, 서버가 String 반환, Int로 흔들릴 수 있어 flexible 디코딩)
    public let id: String
    /// 약관 링크
    public let link: String
    /// 필수 동의 여부
    public let isMandatory: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case link
        case isMandatory
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        link = try container.decodeIfPresent(String.self, forKey: .link) ?? ""
        isMandatory = try container.decodeBoolFlexibleIfPresent(forKey: .isMandatory) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(link, forKey: .link)
        try container.encode(isMandatory, forKey: .isMandatory)
    }
}

// MARK: - Mapping

extension TermsDTO {
    /// Domain 모델로 변환. `termsType`은 서버 응답에 없어 클라이언트가 요청 시점의 값을 부여한다.
    func toDomain(type: TermsType) -> Terms {
        Terms(id: id, type: type, link: link, isMandatory: isMandatory)
    }
}
