//
//  AttendanceTimeWindow.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 출석 시간대 상태 (시간 체크 전용)
///
/// `isWithinAttendanceTime(session:)`에서 현재 시간이 어느 시간대에 속하는지 반환합니다.
public enum AttendanceTimeWindow {
    /// 출석 시간 전 (아직 출석 체크 불가)
    case tooEarly

    /// 정시 출석 가능 시간대 (GPS 출석 가능)
    case onTime

    /// 지각 시간대 (사유 제출 필요)
    case lateWindow

    /// 마감됨 (결석 사유 제출 필요)
    case expired
}
