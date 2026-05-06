//
//  ScheduleLocation.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정 장소 도메인 모델
///
/// 서버 V2 일정 응답의 `location` 객체를 도메인으로 변환한 값입니다.
/// 도메인 레벨에서 `nil` 은 비대면 일정을 의미합니다.
///
/// - SeeAlso: ``V2LocationDTO``
struct ScheduleLocation: Equatable, Sendable {

    /// 위도
    let latitude: Double

    /// 경도
    let longitude: Double

    /// 장소명
    let locationName: String
}
