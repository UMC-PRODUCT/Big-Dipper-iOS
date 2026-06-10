//
//  AttendanceListQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation
import UMCFoundation

/// 운영진용 일정 출석 현황 목록 조회 Query DTO
///
/// `GET /api/v2/schedules/attendance` 쿼리 파라미터.
///
/// - `from` / `to` 미지정 시 서버 기본값(요청 시점 -1개월 ~ +24시간)이 적용됩니다.
/// - `attendanceStatus` 미지정 시 모든 상태를 반환합니다.
///
/// `from` / `to` 는 서버가 UTC ISO8601 datetime 문자열을 기대하므로
/// ``UMCFoundation/ServerDateTimeConverter/toUTCDateTimeString(_:)`` 로 변환합니다.
struct AttendanceListQuery {
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
