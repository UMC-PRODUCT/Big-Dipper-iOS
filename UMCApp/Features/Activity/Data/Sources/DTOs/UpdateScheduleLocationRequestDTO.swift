//
//  UpdateScheduleLocationRequestDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation

/// 세션 출석 위치 변경 요청 DTO
///
/// `PATCH /api/v2/schedules/{scheduleId}` body. 운영진이 일정의 출석 기준 위치만
/// 부분 갱신할 때 사용합니다. 서버는 `{ "location": { ... } }` 형태의 중첩 JSON을
/// 기대하므로 위치 페이로드를 ``Location`` 으로 감싸 인코딩합니다.
///
/// - Note: Schedule/Home 도메인의 위치 타입을 재사용하지 않고 ActivityData 내부에서
///   자체 완결적으로 정의합니다 (모듈 간 결합 회피).
struct UpdateScheduleLocationRequestDTO: Encodable, Sendable {

    /// 위치 변경 페이로드 (`location` 키로 중첩 인코딩)
    let location: Location

    init(latitude: Double, longitude: Double, locationName: String) {
        self.location = Location(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
    }

    /// 일정 위치 중첩 페이로드
    struct Location: Encodable, Sendable {
        /// 위도
        let latitude: Double
        /// 경도
        let longitude: Double
        /// 위치 표시 이름
        let locationName: String
    }
}
