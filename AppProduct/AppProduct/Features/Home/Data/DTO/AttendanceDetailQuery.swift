//
//  AttendanceDetailQuery.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import Foundation

/// 운영진용 단일 일정 출석 현황 조회 Query DTO (SCHEDULE-Q005)
///
/// `GET /api/v2/schedules/{scheduleId}/attendance`
///
/// - `attendanceStatus` 미지정 시 모든 상태 반환 (`requestPlain` 으로 전송)
struct AttendanceDetailQuery: Encodable {
    /// 출석 상태 필터 (옵션)
    let attendanceStatus: String?

    /// Query Parameter Dictionary 변환 (nil 항목은 키 제거)
    var toParameters: [String: Any] {
        guard let attendanceStatus else { return [:] }
        return ["attendanceStatus": attendanceStatus]
    }
}
