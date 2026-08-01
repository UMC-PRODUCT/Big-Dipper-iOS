//
//  ScheduleLocation.swift
//  HomeDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation

/// 일정 장소 도메인 모델
///
/// 서버 V2 일정 응답의 `location` 객체를 도메인으로 변환한 값이다.
/// 컨테이너에서 `nil` 은 비대면 일정을 의미한다.
public struct ScheduleLocation: Equatable, Sendable {

    // MARK: - Property

    /// 위도
    public let latitude: Double

    /// 경도
    public let longitude: Double

    /// 장소명
    public let locationName: String

    // MARK: - Init

    public init(latitude: Double, longitude: Double, locationName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
