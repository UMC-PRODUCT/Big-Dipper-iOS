//
//  ScheduleLocation.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 일정 장소 (`nil` 컨테이너 값 = 비대면)
///
/// > Note: 향후 Schedule Feature 모듈이 분리되면 그쪽으로 이동 예정.
///   현재는 ``ScheduleAttendanceInfo`` 의 의존성을 충족하기 위해 ActivityDomain 에 임시 배치.
public struct ScheduleLocation: Equatable, Sendable {

    public let latitude: Double
    public let longitude: Double
    public let locationName: String

    public init(latitude: Double, longitude: Double, locationName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
