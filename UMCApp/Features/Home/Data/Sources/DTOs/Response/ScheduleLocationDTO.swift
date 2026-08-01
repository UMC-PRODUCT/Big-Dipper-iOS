//
//  ScheduleLocationDTO.swift
//  HomeData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// V2 일정 응답의 `location` 객체 DTO
///
/// 응답에서 `null` 이면 비대면 일정을 의미하므로 상위 DTO 가 옵셔널로 보유한다.
///
/// - SeeAlso: ``HomeDomain/ScheduleLocation``
public struct ScheduleLocationDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 위도
    public let latitude: Double

    /// 경도
    public let longitude: Double

    /// 장소명
    public let locationName: String

    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case locationName
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decodeDoubleFlexibleIfPresent(forKey: .latitude) ?? 0
        longitude = try container.decodeDoubleFlexibleIfPresent(forKey: .longitude) ?? 0
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
    }
}

// MARK: - Domain 변환

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
