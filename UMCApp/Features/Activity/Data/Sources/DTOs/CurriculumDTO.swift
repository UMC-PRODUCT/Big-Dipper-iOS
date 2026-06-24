//
//  CurriculumDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

// MARK: - CurriculumDTO

/// 파트별 커리큘럼 조회 응답 DTO
///
/// `GET /api/v2/curriculums/overview?gisuId={ID}&part={PART}&weekNo={N}`
///
/// 서버 식별자(`curriculumId`)는 `String`, 주차 목록은 `WeeklyCurriculumDTO` 배열로 디코딩한다.
struct CurriculumDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let curriculumId: String
    let title: String
    let weeks: [WeeklyCurriculumDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case curriculumId
        case title
        case weeks
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        curriculumId = try container.decodeFlexibleStringIfPresent(forKey: .curriculumId) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        weeks = try container.decodeIfPresent([WeeklyCurriculumDTO].self, forKey: .weeks) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(curriculumId, forKey: .curriculumId)
        try container.encode(title, forKey: .title)
        try container.encode(weeks, forKey: .weeks)
    }
}

// MARK: - WeeklyCurriculumDTO

/// 주차 커리큘럼 항목 DTO
struct WeeklyCurriculumDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let weeklyCurriculumId: String
    let weekNo: Int
    let title: String
    let startsAt: String
    let endsAt: String
    let isExtra: Bool

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case weeklyCurriculumId
        case weekNo
        case title
        case startsAt
        case endsAt
        case isExtra
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weeklyCurriculumId =
            try container.decodeFlexibleStringIfPresent(forKey: .weeklyCurriculumId) ?? ""
        weekNo = try container.decodeIntFlexibleIfPresent(forKey: .weekNo) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt) ?? ""
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt) ?? ""
        isExtra = try container.decodeBoolFlexibleIfPresent(forKey: .isExtra) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weeklyCurriculumId, forKey: .weeklyCurriculumId)
        try container.encode(weekNo, forKey: .weekNo)
        try container.encode(title, forKey: .title)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encode(endsAt, forKey: .endsAt)
        try container.encode(isExtra, forKey: .isExtra)
    }
}

// MARK: - CurriculumDTO + toDomain

extension CurriculumDTO {

    /// 커리큘럼 진행률 도메인 모델 ``CurriculumProgressModel`` 로 변환한다.
    ///
    /// `part` 는 DTO 본문에 없는 값으로, 조회 요청 시 사용한 파트 문자열을 호출자가 전달한다.
    /// 종료된 주차 수(`completedCount`)는 각 주차 `endsAt` 와 `now` 비교로 계산한다.
    ///
    /// - Parameters:
    ///   - part: 조회 파트의 서버 문자열 (예: `"IOS"`)
    ///   - now: 진행률 계산 기준 시각 (테스트 결정론을 위해 주입 가능)
    func toCurriculumProgress(part: String, now: Date = .now) -> CurriculumProgressModel {
        let partType = UMCPartType(apiValue: part)
        let partName = "\(partType?.name ?? part) PART CURRICULUM"

        let completedCount = weeks.filter { week in
            guard let endDate = week.parsedEndsAt else { return false }
            return now > endDate
        }.count
        let totalCount = weeks.count

        let currentWeekTitle: String = {
            let inProgress = weeks.first { week in
                guard let start = week.parsedStartsAt,
                      let end = week.parsedEndsAt else { return false }
                return start <= now && now <= end
            }
            return inProgress?.title ?? title
        }()

        return CurriculumProgressModel(
            partType: partType,
            partName: partName,
            curriculumTitle: currentWeekTitle,
            completedCount: completedCount,
            totalCount: totalCount
        )
    }

    /// 미션 카드 도메인 모델 목록 ``MissionCardModel`` 로 변환한다 (주차 오름차순 정렬).
    ///
    /// - Parameters:
    ///   - platform: 카드에 표기할 플랫폼/파트 문자열
    ///   - now: 미션 상태 계산 기준 시각 (테스트 결정론을 위해 주입 가능)
    func toMissionCards(platform: String, now: Date = .now) -> [MissionCardModel] {
        weeks
            .map { $0.toMissionCard(platform: platform, now: now) }
            .sorted { $0.week < $1.week }
    }
}

// MARK: - WeeklyCurriculumDTO + Mapping

extension WeeklyCurriculumDTO {

    /// 주차 DTO 를 미션 카드 도메인 모델 ``MissionCardModel`` 로 변환한다.
    func toMissionCard(platform: String, now: Date) -> MissionCardModel {
        MissionCardModel(
            week: weekNo,
            platform: platform,
            title: title,
            missionTitle: title,
            missionType: .link,
            status: missionStatus(now: now),
            isExtra: isExtra
        )
    }

    /// `startsAt` / `endsAt` 와 `now` 를 비교해 미션 상태를 결정한다.
    func missionStatus(now: Date) -> MissionStatus {
        guard let start = parsedStartsAt, let end = parsedEndsAt else {
            return .notStarted
        }
        if now < start {
            return .notStarted
        } else if now <= end {
            return .inProgress
        } else {
            return .completed
        }
    }

    var parsedStartsAt: Date? {
        StudyGroupDateParser.parse(startsAt)
    }

    var parsedEndsAt: Date? {
        StudyGroupDateParser.parse(endsAt)
    }
}
