//
//  ScheduleAttendancePolicy.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 일정별로 다른 출석 시각 임계값
///
/// 체크인 가능 시각, 정시/지각 경계 등 일정마다 달라지는 동적 정책을 표현합니다.
/// 지오펜스 반경 같은 앱 전역 상수는 ``AttendancePolicy`` 를 사용합니다.
///
/// > Note: UMCApp 의 ``AttendancePolicy`` (상수 enum) 와 이름 충돌을 피하기 위해
///   `Schedule` 접두사를 부여했습니다.
public struct ScheduleAttendancePolicy: Equatable, Sendable {

    /// 출석 체크인 시작 시각 (이전엔 출석 불가)
    public let checkInStartAt: Date

    /// 정시 출석 종료 시각 (이후엔 지각)
    public let onTimeEndAt: Date

    /// 지각 종료 시각 (이후엔 결석)
    public let lateEndAt: Date

    public init(checkInStartAt: Date, onTimeEndAt: Date, lateEndAt: Date) {
        self.checkInStartAt = checkInStartAt
        self.onTimeEndAt = onTimeEndAt
        self.lateEndAt = lateEndAt
    }
}
