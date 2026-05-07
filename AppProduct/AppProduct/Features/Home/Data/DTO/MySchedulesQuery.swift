//
//  MySchedulesQuery.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import Foundation

/// 내 일정 목록 조회 Query DTO
///
/// `GET /api/v2/schedules/me`
struct MySchedulesQuery: Encodable {
    /// 조회 시작 시각
    let from: Date
    /// 조회 종료 시각
    let to: Date
    /// 출석 필수 일정만 조회 여부
    let isAttendanceRequired: Bool

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        [
            "from": ServerDateTimeConverter.toUTCDateTimeString(from),
            "to": ServerDateTimeConverter.toUTCDateTimeString(to),
            "isAttendanceRequired": isAttendanceRequired
        ]
    }
}
