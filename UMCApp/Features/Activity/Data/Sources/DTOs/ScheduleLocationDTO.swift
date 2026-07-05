//
//  ScheduleLocationDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/10/26.
//

import Foundation
import UMCFoundation
import ActivityDomain

/// 출석 현황 응답의 `location` 객체 DTO
///
/// 일정의 출석 기준 장소. 응답에서 `null` 이면 비대면 일정을 의미하므로 상위 DTO 에서
/// 옵셔널로 보유합니다.
///
/// - SeeAlso: ``ActivityDomain/ScheduleLocation``
struct ScheduleLocationDTO: Codable, Sendable, Equatable {

    /// 위도
    let latitude: Double

    /// 경도
    let longitude: Double

    /// 장소명
    let locationName: String

    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case locationName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decodeDoubleFlexibleIfPresent(forKey: .latitude) ?? 0
        longitude = try container.decodeDoubleFlexibleIfPresent(forKey: .longitude) ?? 0
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
    }
}

// MARK: - Domain Mapping

extension ScheduleLocationDTO {

    /// DTO → 도메인 변환
    func toDomain() -> ScheduleLocation {
        ScheduleLocation(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
    }
}
