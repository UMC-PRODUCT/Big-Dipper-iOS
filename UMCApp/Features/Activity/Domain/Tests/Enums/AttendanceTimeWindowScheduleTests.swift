//
//  AttendanceTimeWindowScheduleTests.swift
//  ActivityDomainTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import HomeDomain
import Testing
@testable import ActivityDomain

// MARK: - Helpers

/// 결정론적 기준 시각: epoch 10_000. 모든 케이스가 이 값을 기준으로 상대 정의된다.
private let fixedNow = Date(timeIntervalSince1970: 10_000)

private let onTimeSec = TimeInterval(AttendancePolicy.onTimeThresholdMinutes * 60)
private let lateSec = TimeInterval(AttendancePolicy.lateThresholdMinutes * 60)

private func makeSchedule(
    startsAt: Date,
    endsAt: Date,
    attendancePolicy: ScheduleAttendancePolicy? = nil
) -> ScheduleDetailData {
    ScheduleDetailData(
        scheduleId: "1",
        name: "정기 세션",
        description: "",
        tags: [],
        startsAt: startsAt,
        endsAt: endsAt,
        isParticipant: true,
        attendancePolicy: attendancePolicy
    )
}

// MARK: - 상수 기반 판정

@Suite("AttendanceTimeWindow — 클라이언트 상수 기반 판정")
struct AttendanceTimeWindowConstantTests {

    @Test("일반 — 시작 onTime 임계 이전 → tooEarly")
    func nonAllDayTooEarly() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(onTimeSec + 60),
            endsAt: fixedNow.addingTimeInterval(onTimeSec + 3_600),
            isAllDay: false,
            now: fixedNow
        )
        #expect(window == .tooEarly)
    }

    @Test("일반 — onTime 경계값(now == start + onTime) → onTime (boundary 포함)")
    func nonAllDayOnTimeUpperBoundary() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(-onTimeSec),
            endsAt: fixedNow.addingTimeInterval(3_600),
            isAllDay: false,
            now: fixedNow
        )
        #expect(window == .onTime)
    }

    @Test("일반 — onTime 초과 ~ late 임계 → lateWindow")
    func nonAllDayLateWindow() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(-(onTimeSec + 60)),
            endsAt: fixedNow.addingTimeInterval(3_600),
            isAllDay: false,
            now: fixedNow
        )
        #expect(window == .lateWindow)
    }

    @Test("일반 — late 임계 초과 → expired")
    func nonAllDayExpired() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(-(lateSec + 60)),
            endsAt: fixedNow.addingTimeInterval(3_600),
            isAllDay: false,
            now: fixedNow
        )
        #expect(window == .expired)
    }

    @Test("종일 — 시작 onTime 임계 이전 → tooEarly")
    func allDayTooEarly() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(onTimeSec + 60),
            endsAt: fixedNow.addingTimeInterval(onTimeSec + 86_400),
            isAllDay: true,
            now: fixedNow
        )
        #expect(window == .tooEarly)
    }

    @Test("종일 — late 임계를 지나도 종료 전이면 onTime (lateWindow 미분기)")
    func allDayStaysOnTimeUntilEnd() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(-(lateSec + 3_600)),
            endsAt: fixedNow.addingTimeInterval(3_600),
            isAllDay: true,
            now: fixedNow
        )
        #expect(window == .onTime)
    }

    @Test("종일 — 종료 시각 지남 → expired")
    func allDayExpired() {
        let window = AttendanceTimeWindow(
            startsAt: fixedNow.addingTimeInterval(-86_400),
            endsAt: fixedNow.addingTimeInterval(-60),
            isAllDay: true,
            now: fixedNow
        )
        #expect(window == .expired)
    }
}

// MARK: - 서버 정책 기반 판정

@Suite("AttendanceTimeWindow — 서버 출석 정책 기반 판정")
struct AttendanceTimeWindowPolicyTests {

    private static let policy = ScheduleAttendancePolicy(
        checkInStartAt: fixedNow.addingTimeInterval(-600),
        onTimeEndAt: fixedNow.addingTimeInterval(600),
        lateEndAt: fixedNow.addingTimeInterval(1_800)
    )

    private func window(now: Date) -> AttendanceTimeWindow {
        AttendanceTimeWindow(
            policy: Self.policy,
            // 정책이 있으면 무시되는 값들 — 폴백 경로와 다른 결과가 나오도록 일부러 어긋나게 둔다.
            startsAt: fixedNow.addingTimeInterval(-86_400),
            endsAt: fixedNow.addingTimeInterval(-86_000),
            isAllDay: false,
            now: now
        )
    }

    @Test("체크인 시작 전 → tooEarly")
    func beforeCheckInStart() {
        #expect(window(now: fixedNow.addingTimeInterval(-601)) == .tooEarly)
    }

    @Test("체크인 시작 ~ 정시 마감 → onTime (양 경계 포함)")
    func withinOnTime() {
        #expect(window(now: fixedNow.addingTimeInterval(-600)) == .onTime)
        #expect(window(now: fixedNow.addingTimeInterval(600)) == .onTime)
    }

    @Test("정시 마감 초과 ~ 지각 마감 → lateWindow (경계 포함)")
    func withinLateWindow() {
        #expect(window(now: fixedNow.addingTimeInterval(601)) == .lateWindow)
        #expect(window(now: fixedNow.addingTimeInterval(1_800)) == .lateWindow)
    }

    @Test("지각 마감 초과 → expired")
    func afterLateEnd() {
        #expect(window(now: fixedNow.addingTimeInterval(1_801)) == .expired)
    }

    @Test("정책 nil → 클라이언트 상수 경로와 동일한 결과")
    func nilPolicyFallsBackToConstants() {
        let startsAt = fixedNow.addingTimeInterval(-(onTimeSec + 60))
        let endsAt = fixedNow.addingTimeInterval(3_600)

        let fallback = AttendanceTimeWindow(
            policy: nil,
            startsAt: startsAt,
            endsAt: endsAt,
            isAllDay: false,
            now: fixedNow
        )
        let constant = AttendanceTimeWindow(
            startsAt: startsAt,
            endsAt: endsAt,
            isAllDay: false,
            now: fixedNow
        )

        #expect(fallback == constant)
        #expect(fallback == .lateWindow)
    }
}

// MARK: - 일정 기반 편의 진입점

@Suite("AttendanceTimeWindow — ScheduleDetailData 위임")
struct AttendanceTimeWindowScheduleDelegationTests {

    @Test("정책이 붙은 일정은 정책 분기를 따른다")
    func scheduleUsesAttachedPolicy() {
        let schedule = makeSchedule(
            // 상수 경로였다면 expired 가 될 과거 일정.
            startsAt: fixedNow.addingTimeInterval(-86_400),
            endsAt: fixedNow.addingTimeInterval(-86_000),
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: fixedNow.addingTimeInterval(-600),
                onTimeEndAt: fixedNow.addingTimeInterval(600),
                lateEndAt: fixedNow.addingTimeInterval(1_800)
            )
        )
        #expect(AttendanceTimeWindow(schedule: schedule, now: fixedNow) == .onTime)
    }

    @Test("정책 없는 일정은 상수 분기로 폴백한다")
    func scheduleWithoutPolicyFallsBack() {
        let schedule = makeSchedule(
            startsAt: fixedNow.addingTimeInterval(onTimeSec + 60),
            endsAt: fixedNow.addingTimeInterval(onTimeSec + 3_600)
        )
        #expect(AttendanceTimeWindow(schedule: schedule, now: fixedNow) == .tooEarly)
    }

    @Test("now 기본값 — 먼 미래 일정은 tooEarly")
    func defaultNowUsesCurrentDate() {
        let now = Date()
        let schedule = makeSchedule(
            startsAt: now.addingTimeInterval(3_600),
            endsAt: now.addingTimeInterval(7_200)
        )
        #expect(AttendanceTimeWindow(schedule: schedule) == .tooEarly)
    }
}
