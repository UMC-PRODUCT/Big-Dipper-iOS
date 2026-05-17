//
//  AttendanceTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/8/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("Attendance — 빌더 메서드 (도메인 규칙)")
struct AttendanceTests {

    // MARK: - Helper

    private func makeBase(
        status: AttendanceStatus = .beforeAttendance,
        type: AttendanceType = .gps,
        reason: String? = nil,
        verification: LocationVerification? = nil
    ) -> Attendance {
        Attendance(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            type: type,
            status: status,
            locationVerification: verification,
            reason: reason
        )
    }

    private func makeVerification() -> LocationVerification {
        LocationVerification(
            isVerified: true,
            coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
            address: Address(fullAddress: "서울 강남구 테헤란로 1", city: "서울", district: "강남구"),
            verifiedAt: Date(timeIntervalSince1970: 0)
        )
    }

    // MARK: - approved(with:)

    @Test("approved(with:) 호출 시 status 가 .present 로 변경되고 verification 이 첨부된다")
    func approvedSetsPresentWithVerification() {
        let original = makeBase(status: .beforeAttendance)
        let verification = makeVerification()

        let result = original.approved(with: verification)

        #expect(result.status == .present)
        #expect(result.locationVerification == verification)
        #expect(result.sessionId == original.sessionId)
        #expect(result.userId == original.userId)
    }

    @Test("approved(with:) 는 reason 을 변경하지 않는다 (기존 값 보존)")
    func approvedPreservesReason() {
        let original = makeBase(status: .late, reason: "지각 사유")

        let result = original.approved(with: makeVerification())

        #expect(result.reason == "지각 사유")
    }

    // MARK: - beforeAttendance()

    @Test("beforeAttendance() 호출 시 status 가 .beforeAttendance 로 리셋된다")
    func beforeAttendanceResetsStatus() {
        let original = makeBase(status: .present)

        let result = original.beforeAttendance()

        #expect(result.status == .beforeAttendance)
    }

    @Test("beforeAttendance() 는 verification/reason 을 그대로 유지한다")
    func beforeAttendancePreservesOtherFields() {
        let verification = makeVerification()
        let original = makeBase(
            status: .late,
            reason: "기존 사유",
            verification: verification
        )

        let result = original.beforeAttendance()

        #expect(result.locationVerification == verification)
        #expect(result.reason == "기존 사유")
    }

    // MARK: - rejected(status:)

    @Test(
        "rejected(status:) 는 인자로 받은 status 로 교체한다",
        arguments: [
            AttendanceStatus.absent,
            .late,
            .pendingApproval
        ]
    )
    func rejectedSetsGivenStatus(_ targetStatus: AttendanceStatus) {
        let original = makeBase(status: .present)

        let result = original.rejected(status: targetStatus)

        #expect(result.status == targetStatus)
    }

    // MARK: - late(reason:)

    @Test("late(reason:) 는 status=.late 로 변경하고 reason 을 첨부한다")
    func lateSetsLateAndReason() {
        let original = makeBase(status: .beforeAttendance)

        let result = original.late(reason: "버스 지연")

        #expect(result.status == .late)
        #expect(result.reason == "버스 지연")
    }

    @Test("late(reason:) 호출은 기존 reason 을 덮어쓴다")
    func lateOverwritesPreviousReason() {
        let original = makeBase(status: .beforeAttendance, reason: "이전 사유")

        let result = original.late(reason: "새 사유")

        #expect(result.reason == "새 사유")
    }

    // MARK: - absent(reason:)

    @Test("absent(reason:) 는 status=.absent 로 변경하고 reason 을 첨부한다")
    func absentSetsAbsentAndReason() {
        let original = makeBase(status: .beforeAttendance)

        let result = original.absent(reason: "본인 사정")

        #expect(result.status == .absent)
        #expect(result.reason == "본인 사정")
    }

    // MARK: - 빌더 체이닝 (도메인 흐름)

    @Test("출석 전 → 지각 사유 제출 → 운영자 거절(absent) 흐름")
    func chainBeforeAttendanceLateRejected() {
        let initial = makeBase(status: .beforeAttendance)

        let lateRequested = initial.late(reason: "교통 정체")
        let rejected = lateRequested.rejected(status: .absent)

        #expect(rejected.status == .absent)
        #expect(rejected.reason == "교통 정체")  // reason 은 보존
    }

    @Test("승인된 출석은 sessionId/userId 를 절대 변경하지 않는다")
    func approvedKeepsIdentity() {
        let original = makeBase(status: .beforeAttendance)
        let originalSessionId = original.sessionId
        let originalUserId = original.userId

        let result = original.approved(with: makeVerification())

        #expect(result.sessionId == originalSessionId)
        #expect(result.userId == originalUserId)
    }
}
