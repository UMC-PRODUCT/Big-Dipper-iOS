//
//  OperatorSessionAttendanceTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

@MainActor
@Suite("OperatorSessionAttendance — copyWith 집계 규칙 (도메인 규칙)")
struct OperatorSessionAttendanceTests {

    // MARK: - Helper

    private func makeSession() -> Session {
        let info = SessionInfo(
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "1주차 OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )
        return Session(info: info)
    }

    private func makeMember(name: String = "홍길동") -> OperatorPendingMember {
        OperatorPendingMember(
            name: name,
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeAttendance(
        attendedCount: Int = 5,
        totalCount: Int = 10,
        pendingCount: Int = 2,
        pendingMembers: [OperatorPendingMember] = []
    ) -> OperatorSessionAttendance {
        OperatorSessionAttendance(
            session: makeSession(),
            attendanceRate: totalCount > 0
                ? Double(attendedCount) / Double(totalCount)
                : 0.0,
            attendedCount: attendedCount,
            totalCount: totalCount,
            pendingCount: pendingCount,
            pendingMembers: pendingMembers
        )
    }

    // MARK: - isAllApproved

    @Test("pendingCount==0 이면 isAllApproved=true")
    func allApprovedWhenPendingZero() {
        let attendance = makeAttendance(pendingCount: 0)

        #expect(attendance.isAllApproved == true)
    }

    @Test("pendingCount>0 이면 isAllApproved=false")
    func notApprovedWhenPendingExists() {
        let attendance = makeAttendance(pendingCount: 3)

        #expect(attendance.isAllApproved == false)
    }

    // MARK: - copyWith

    @Test("copyWith(attendedCount:) 변경 시 attendanceRate 가 자동 재계산된다")
    func copyWithAttendedCountRecalculatesRate() {
        let original = makeAttendance(attendedCount: 5, totalCount: 10)

        let updated = original.copyWith(attendedCount: 8)

        #expect(updated.attendedCount == 8)
        #expect(updated.attendanceRate == 0.8)
    }

    @Test("totalCount 가 0이면 attendanceRate 는 0.0")
    func copyWithZeroTotalGivesZeroRate() {
        let original = makeAttendance(attendedCount: 0, totalCount: 0)

        let updated = original.copyWith(attendedCount: 0)

        #expect(updated.attendanceRate == 0.0)
    }

    @Test("copyWith(pendingMembers:) 명시 시 해당 멤버 목록으로 갱신된다")
    func copyWithPendingMembersUpdatesList() {
        let original = makeAttendance(pendingMembers: [])
        let m1 = makeMember(name: "A")
        let m2 = makeMember(name: "B")

        let updated = original.copyWith(pendingMembers: [m1, m2])

        #expect(updated.pendingMembers.count == 2)
    }

    @Test("pendingCount 미지정 시 pendingMembers.count 가 자동 적용된다")
    func copyWithPendingCountFromMembers() {
        let original = makeAttendance(pendingCount: 0, pendingMembers: [])
        let members = [makeMember(name: "A"), makeMember(name: "B")]

        let updated = original.copyWith(pendingMembers: members)

        #expect(updated.pendingCount == 2)
    }

    @Test("pendingCount 명시 시 그 값이 우선한다 (members.count 보다 우선)")
    func copyWithExplicitPendingCountWins() {
        let original = makeAttendance()
        let members = [makeMember(name: "A"), makeMember(name: "B")]

        let updated = original.copyWith(pendingCount: 99, pendingMembers: members)

        #expect(updated.pendingCount == 99)
        #expect(updated.pendingMembers.count == 2)
    }

    @Test("아무것도 지정하지 않으면 기존 값이 유지된다")
    func copyWithNoChangesKeepsOriginal() {
        let original = makeAttendance(
            attendedCount: 5,
            totalCount: 10,
            pendingCount: 3
        )

        let updated = original.copyWith()

        #expect(updated.attendedCount == 5)
        #expect(updated.pendingCount == 3)
        #expect(updated.attendanceRate == original.attendanceRate)
    }

    // MARK: - Identity

    @Test("copyWith 결과는 동일한 id 를 유지한다")
    func copyWithKeepsIdentity() {
        let original = makeAttendance()

        let updated = original.copyWith(attendedCount: 100)

        #expect(updated.id == original.id)
    }
}
