//
//  V2LocationDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// V2 일정 API 의 `location` 객체 DTO
///
/// 요청·응답 양쪽에서 사용됩니다.
/// 요청 본문에서 `null` 로 보내면 비대면 일정으로 해석되며,
/// 응답에서 `null` 로 내려와도 동일한 의미입니다.
///
/// - SeeAlso: ``ScheduleLocation``
struct V2LocationDTO: Codable, Sendable, Equatable {

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

    init(latitude: Double, longitude: Double, locationName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
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

extension V2LocationDTO {

    /// DTO → 도메인 변환
    func toDomain() -> ScheduleLocation {
        ScheduleLocation(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
    }

    /// 도메인 → DTO 변환
    init(domain: ScheduleLocation) {
        self.latitude = domain.latitude
        self.longitude = domain.longitude
        self.locationName = domain.locationName
    }
}

private extension KeyedDecodingContainer {
    func decodeDoubleFlexible(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let doubleValue = Double(value) {
            return doubleValue
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Double/String-number/Int for key '\(key.stringValue)'"
            )
        )
    }

    func decodeDoubleFlexibleIfPresent(forKey key: Key) throws -> Double? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeDoubleFlexible(forKey: key)
    }
}
