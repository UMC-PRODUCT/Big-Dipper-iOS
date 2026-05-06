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
