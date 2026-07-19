//
//  ScheduleAttendanceInfoTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

private func makeParticipant(
    memberId: String = "1",
    status: ParticipantAttendanceStatus
) -> ParticipantAttendance {
    ParticipantAttendance(
        memberId: memberId,
        name: "참여자\(memberId)",
        nickname: "닉\(memberId)",
        profileImageURL: "",
        schoolId: "1",
        schoolName: "한성대",
        attendanceStatus: status,
        isLocationVerified: false,
        excuseReason: nil
    )
}

private func makeInfo(participants: [ParticipantAttendance]) -> ScheduleAttendanceInfo {
    ScheduleAttendanceInfo(
        scheduleId: "100",
        name: "정기 세션",
        description: "",
        startsAt: Date(timeIntervalSince1970: 1_736_942_400),
        endsAt: Date(timeIntervalSince1970: 1_736_949_600),
        location: nil,
        isOnline: true,
        authorMemberId: "1",
        attendancePolicy: nil,
        tags: [],
        participants: participants
    )
}

// MARK: - Suite

@Suite("ScheduleAttendanceInfo — 카운팅 / 출석률 / 진행 판정 (도메인 규칙)")
struct ScheduleAttendanceInfoTests {

    // MARK: - presentCount

    @Test("presentCount 는 PRESENT / LATE / EXCUSED 인 참여자만 센다")
    func presentCountCountsPresentLateExcused() {
        // Given
        let info = makeInfo(participants: [
            makeParticipant(memberId: "1", status: .present),
            makeParticipant(memberId: "2", status: .late),
            makeParticipant(memberId: "3", status: .excused),
            makeParticipant(memberId: "4", status: .absent),
            makeParticipant(memberId: "5", status: .pending),
            makeParticipant(memberId: "6", status: .presentPending)
        ])

        // When
        let count = info.presentCount

        // Then
        #expect(count == 3)
    }

    @Test("참여자가 없으면 presentCount 는 0 이다")
    func presentCountIsZeroForEmpty() {
        // Given
        let info = makeInfo(participants: [])

        // When
        let count = info.presentCount

        // Then
        #expect(count == 0)
    }

    // MARK: - pendingCount

    @Test("pendingCount 는 *_PENDING 계열 참여자만 센다")
    func pendingCountCountsPendingFamily() {
        // Given
        let info = makeInfo(participants: [
            makeParticipant(memberId: "1", status: .presentPending),
            makeParticipant(memberId: "2", status: .latePending),
            makeParticipant(memberId: "3", status: .excusedPending),
            makeParticipant(memberId: "4", status: .present),
            makeParticipant(memberId: "5", status: .pending)
        ])

        // When
        let count = info.pendingCount

        // Then
        #expect(count == 3)
    }

    // MARK: - totalCount

    @Test("totalCount 는 participants 배열 길이와 같다")
    func totalCountMatchesParticipantsLength() {
        // Given
        let info = makeInfo(participants: [
            makeParticipant(memberId: "1", status: .present),
            makeParticipant(memberId: "2", status: .absent)
        ])

        // When
        let count = info.totalCount

        // Then
        #expect(count == 2)
    }

    // MARK: - attendanceRate (경계값 포함)

    @Test("attendanceRate 는 presentCount / totalCount 비율을 반환한다")
    func attendanceRateReturnsRatio() {
        // Given
        let info = makeInfo(participants: [
            makeParticipant(memberId: "1", status: .present),
            makeParticipant(memberId: "2", status: .late),
            makeParticipant(memberId: "3", status: .absent),
            makeParticipant(memberId: "4", status: .pending)
        ])

        // When
        let rate = info.attendanceRate

        // Then
        #expect(rate == 0.5)
    }

    @Test("totalCount 가 0 이면 attendanceRate 는 0.0 으로 폴백한다 (0 나누기 방지)")
    func attendanceRateIsZeroWhenTotalIsZero() {
        // Given
        let info = makeInfo(participants: [])

        // When
        let rate = info.attendanceRate

        // Then
        #expect(rate == 0.0)
    }

    @Test("모든 참여자가 출석으로 인정되면 attendanceRate 는 1.0 이다")
    func attendanceRateIsOneWhenAllPresent() {
        // Given
        let info = makeInfo(participants: [
            makeParticipant(memberId: "1", status: .present),
            makeParticipant(memberId: "2", status: .excused),
            makeParticipant(memberId: "3", status: .late)
        ])

        // When
        let rate = info.attendanceRate

        // Then
        #expect(rate == 1.0)
    }

    // MARK: - isOngoing (경계값 포함)

    // makeInfo 고정 범위: startsAt 1_736_942_400 ... endsAt 1_736_949_600
    @Test(
        "isOngoing 은 startsAt...endsAt 경계를 포함해 판정한다",
        arguments: [
            (timestamp: 1_736_942_399.0, expected: false),  // 시작 1초 전
            (timestamp: 1_736_942_400.0, expected: true),   // 시작 시각 (경계)
            (timestamp: 1_736_946_000.0, expected: true),   // 진행 중
            (timestamp: 1_736_949_600.0, expected: true),   // 종료 시각 (경계)
            (timestamp: 1_736_949_601.0, expected: false)   // 종료 1초 후
        ]
    )
    func isOngoingIncludesBoundaries(testCase: (timestamp: Double, expected: Bool)) {
        // Given
        let info = makeInfo(participants: [])

        // When
        let result = info.isOngoing(at: Date(timeIntervalSince1970: testCase.timestamp))

        // Then
        #expect(result == testCase.expected)
    }
}
