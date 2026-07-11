import Foundation
import HomeDomain
import UMCFoundation

/// 일정 목록/상세 응답 DTO (V2)
///
/// `GET /api/v2/schedules/me` 목록과 `GET /api/v2/schedules/{id}` 상세 응답이 동일한
/// 형태로 내려오므로 단일 DTO로 처리한다. 슬라이스 2(#914)는 캘린더 표시에 필요한
/// 필드만 다루며, 장소/참여자/출석 정책 등은 이후 슬라이스에서 확장한다.
///
/// - SeeAlso: ``ScheduleDetailData``
public struct ScheduleDetailDTO: Codable {

    // MARK: - Property

    /// 일정 고유 식별자. 서버 정수를 절대 규칙 #2에 따라 `String`으로 보존한다.
    public let scheduleId: String
    public let name: String
    public let description: String
    public let tags: [String]
    /// 시작 일시 (UTC ISO8601 문자열). 파싱은 호출부(Repository)에서 수행한다.
    public let startsAt: String
    /// 종료 일시 (UTC ISO8601 문자열)
    public let endsAt: String
    /// 현재 사용자의 참여 여부
    public let isParticipant: Bool

    private enum CodingKeys: String, CodingKey {
        case scheduleId
        case name
        case description
        case tags
        case startsAt
        case endsAt
        case isParticipant
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduleId = try container.decodeFlexibleString(forKey: .scheduleId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt) ?? ""
        isParticipant = try container.decodeBoolFlexibleIfPresent(forKey: .isParticipant) ?? false
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(tags, forKey: .tags)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encode(endsAt, forKey: .endsAt)
        try container.encode(isParticipant, forKey: .isParticipant)
    }
}

// MARK: - Domain 변환

extension ScheduleDetailDTO {

    /// DTO → `ScheduleDetailData` 변환. 날짜 파싱 실패 시 현재 시각으로 폴백한다.
    func toDomain() -> ScheduleDetailData {
        ScheduleDetailData(
            scheduleId: scheduleId,
            name: name,
            description: description,
            tags: tags,
            startsAt: ServerDateTimeConverter.parseUTCDateTime(startsAt) ?? .now,
            endsAt: ServerDateTimeConverter.parseUTCDateTime(endsAt) ?? .now,
            isParticipant: isParticipant
        )
    }
}
