//
//  AttendanceDetailQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/6/26.
//

import Foundation

/// 운영진용 단일 일정 출석 현황 조회 Query DTO
///
/// `GET /api/v2/schedules/{scheduleId}/attendance` 쿼리 파라미터.
///
/// - `attendanceStatus` 미지정 시 모든 상태를 반환합니다. 이 경우 파라미터가 비어
///   라우터가 `requestPlain` 으로 전송하도록 빈 딕셔너리를 반환합니다.
struct AttendanceDetailQuery: Encodable {
    /// 출석 상태 필터 (옵션)
    let attendanceStatus: String?

    /// Query Parameter Dictionary 변환 (nil 항목은 키 제거)
    var toParameters: [String: Any] {
        guard let attendanceStatus else { return [:] }
        return ["attendanceStatus": attendanceStatus]
    }
}
