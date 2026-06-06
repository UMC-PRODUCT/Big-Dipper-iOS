//
//  AttendanceDecisionResultTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

private let fixedSessionId = SessionID(value: "session_1")
private let fixedUserId = UserID(value: "user_1")

private func makeResult(
    status: ParticipantAttendanceStatus,
    excuseReason: String? = nil,
    decisionReason: String? = nil
) -> AttendanceDecisionResult {
    AttendanceDecisionResult(
        status: status,
        decidedAt: nil,
        decisionReason: decisionReason,
        excuseReason: excuseReason,
        latitude: nil,
        longitude: nil,
        decisionMakerMemberInfo: nil,
        isPendingDecision: false
    )
}

// MARK: - Suite

@Suite("AttendanceDecisionResult — Attendance 어댑팅 도메인 규칙")
struct AttendanceDecisionResultTests {

    // MARK: - status 매핑

    @Test(
        "출석/지각/결석은 V1 동일 케이스로 매핑된다",
        arguments: [
            (ParticipantAttendanceStatus.present, AttendanceStatus.present),
            (.late, .late),
            (.absent, .absent)
        ]
    )
    func mapsIdenticalCases(
        v2: ParticipantAttendanceStatus,
        expected: AttendanceStatus
    ) {
        // Given
        let result = makeResult(status: v2)

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.status == expected)
    }

    @Test("사유 결석(excused)은 출석(present)으로 인정 매핑된다")
    func mapsExcusedToPresent() {
        // Given
        let result = makeResult(status: .excused)

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.status == .present)
    }

    @Test(
        "*_PENDING 계열은 모두 pendingApproval 로 합쳐진다",
        arguments: [
            ParticipantAttendanceStatus.presentPending,
            .latePending,
            .excusedPending
        ]
    )
    func mapsPendingFamilyToPendingApproval(v2: ParticipantAttendanceStatus) {
        // Given
        let result = makeResult(status: v2)

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.status == .pendingApproval)
    }

    @Test(
        "pending / unknown 은 beforeAttendance 로 매핑된다",
        arguments: [
            ParticipantAttendanceStatus.pending,
            .unknown
        ]
    )
    func mapsPendingOrUnknownToBeforeAttendance(v2: ParticipantAttendanceStatus) {
        // Given
        let result = makeResult(status: v2)

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.status == .beforeAttendance)
    }

    // MARK: - type 결정

    @Test("excuseReason 이 있으면 type = .reason 이다 (사유 출석)")
    func attendanceTypeIsReasonWhenExcuseReasonPresent() {
        // Given
        let result = makeResult(status: .excused, excuseReason: "병원 진료")

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.type == .reason)
    }

    @Test("excuseReason 이 nil 이면 type = .gps 이다 (GPS 출석)")
    func attendanceTypeIsGPSWhenExcuseReasonNil() {
        // Given
        let result = makeResult(status: .present, excuseReason: nil)

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.type == .gps)
    }

    // MARK: - reason 우선순위

    @Test("reason 은 excuseReason 우선, 없으면 decisionReason 을 채택한다")
    func reasonPrefersExcuseOverDecision() {
        // Given
        let withBoth = makeResult(
            status: .excused,
            excuseReason: "사유 텍스트",
            decisionReason: "결정 텍스트"
        )
        let withoutExcuse = makeResult(
            status: .present,
            excuseReason: nil,
            decisionReason: "결정 텍스트만"
        )

        // When
        let attendanceWithBoth = withBoth.toAttendance(
            sessionId: fixedSessionId,
            userId: fixedUserId
        )
        let attendanceWithoutExcuse = withoutExcuse.toAttendance(
            sessionId: fixedSessionId,
            userId: fixedUserId
        )

        // Then
        #expect(attendanceWithBoth.reason == "사유 텍스트")
        #expect(attendanceWithoutExcuse.reason == "결정 텍스트만")
    }

    @Test("excuseReason 도 decisionReason 도 nil 이면 reason 은 nil 이다")
    func reasonIsNilWhenBothNil() {
        // Given
        let result = makeResult(
            status: .present,
            excuseReason: nil,
            decisionReason: nil
        )

        // When
        let attendance = result.toAttendance(sessionId: fixedSessionId, userId: fixedUserId)

        // Then
        #expect(attendance.reason == nil)
    }
}
