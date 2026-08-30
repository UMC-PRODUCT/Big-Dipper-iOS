//
//  AttendanceTimeWindow+Schedule.swift
//  ActivityDomain
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import HomeDomain

// MARK: - 출석 시간대 판정 (순수 함수)

extension AttendanceTimeWindow {

    /// 클라이언트 상수(`AttendancePolicy`) 기반 판정.
    ///
    /// 서버 출석 정책이 붙지 않은 일정/세션에 쓰는 폴백 규칙이다.
    /// 종일 일정은 지각 구간을 두지 않고 종료 시각까지 전부 정시로 본다.
    public init(startsAt: Date, endsAt: Date, isAllDay: Bool, now: Date) {
        let onTimeThreshold = TimeInterval(
            AttendancePolicy.onTimeThresholdMinutes * 60
        )
        let lateThreshold = TimeInterval(
            AttendancePolicy.lateThresholdMinutes * 60
        )

        if isAllDay {
            if now < startsAt.addingTimeInterval(-onTimeThreshold) {
                self = .tooEarly
            } else if now <= endsAt {
                self = .onTime
            } else {
                self = .expired
            }
            return
        }

        if now < startsAt.addingTimeInterval(-onTimeThreshold) {
            self = .tooEarly
        } else if now <= startsAt.addingTimeInterval(onTimeThreshold) {
            self = .onTime
        } else if now <= startsAt.addingTimeInterval(lateThreshold) {
            self = .lateWindow
        } else {
            self = .expired
        }
    }

    /// 서버 출석 정책 우선 판정 — `policy` 가 `nil` 이면 클라이언트 상수로 폴백한다.
    public init(
        policy: ScheduleAttendancePolicy?,
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool,
        now: Date
    ) {
        guard let policy else {
            self.init(startsAt: startsAt, endsAt: endsAt, isAllDay: isAllDay, now: now)
            return
        }

        if now < policy.checkInStartAt {
            self = .tooEarly
        } else if now <= policy.onTimeEndAt {
            self = .onTime
        } else if now <= policy.lateEndAt {
            self = .lateWindow
        } else {
            self = .expired
        }
    }

    /// 일정(canonical `HomeDomain` 모델) 기반 편의 진입점.
    public init(schedule: ScheduleDetailData, now: Date = Date()) {
        self.init(
            policy: schedule.attendancePolicy,
            startsAt: schedule.startsAt,
            endsAt: schedule.endsAt,
            isAllDay: schedule.isAllDay,
            now: now
        )
    }
}
