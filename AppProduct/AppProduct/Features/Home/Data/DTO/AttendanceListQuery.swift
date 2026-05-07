//
//  AttendanceListQuery.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 운영진용 일정 출석 현황 목록 조회 Query DTO (SCHEDULE-Q004)
///
/// `GET /api/v2/schedules/attendance`
///
/// - `from` / `to` 미지정 시 서버 기본값(요청 시점 -1개월 ~ +24시간) 적용
/// - `attendanceStatus` 미지정 시 모든 상태 반환
struct AttendanceListQuery: Encodable {
    /// 조회 시작 시각 (옵션)
    let from: Date?
    /// 조회 종료 시각 (옵션)
    let to: Date?
    /// 출석 상태 필터 (옵션)
    let attendanceStatus: String?

    /// Query Parameter Dictionary 변환 (nil 항목은 키 제거)
    var toParameters: [String: Any] {
        var params: [String: Any] = [:]
        if let from {
            params["from"] = ServerDateTimeConverter.toUTCDateTimeString(from)
        }
        if let to {
            params["to"] = ServerDateTimeConverter.toUTCDateTimeString(to)
        }
        if let attendanceStatus {
            params["attendanceStatus"] = attendanceStatus
        }
        return params
    }
}
