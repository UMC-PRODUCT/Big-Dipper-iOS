//
//  OperatorPendingMemberTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/8/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("OperatorPendingMember — computed property + 매퍼 (도메인 규칙)")
struct OperatorPendingMemberTests {

    // MARK: - hasReason

    @Test("reason 이 nil 이면 hasReason=false")
    func hasReasonNilReturnsFalse() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: nil
        )

        #expect(member.hasReason == false)
    }

    @Test("reason 이 빈 문자열이면 hasReason=false (공백 포함 안된 케이스)")
    func hasReasonEmptyStringReturnsFalse() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: ""
        )

        #expect(member.hasReason == false)
    }

    @Test("reason 에 내용이 있으면 hasReason=true")
    func hasReasonWithContentReturnsTrue() {
        let member = OperatorPendingMember(
            name: "홍길동",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0),
            reason: "교통 지연"
        )

        #expect(member.hasReason == true)
    }

    // MARK: - displayName

    @Test("nickname 이 있으면 'nickname/name' 형태로 표시된다")
    func displayNameWithNickname() {
        let member = OperatorPendingMember(
            name: "홍길동",
            nickname: "길동이",
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0)
        )

        #expect(member.displayName == "길동이/홍길동")
    }

    @Test("nickname 이 nil 이면 name 만 표시된다")
    func displayNameWithoutNickname() {
        let member = OperatorPendingMember(
            name: "홍길동",
            nickname: nil,
            university: "한성대",
            requestTime: Date(timeIntervalSince1970: 0)
        )

        #expect(member.displayName == "홍길동")
    }

    // MARK: - init(from: PendingAttendanceRecord)

    @Test("PendingAttendanceRecord → OperatorPendingMember 변환 — 핵심 필드 매핑")
    func mapsRecordToMemberCoreFields() {
        let record = PendingAttendanceRecord(
            attendanceId: 42,
            memberId: "M-1",
            memberName: "김철수",
            nickname: "철수",
            profileImageLink: URL(string: "https://example.com/profile.png"),
            schoolName: "한성대",
            status: .pendingApproval,
            reason: "회의 지연",
            requestedAt: Date(timeIntervalSince1970: 1000)
        )

        let member = OperatorPendingMember(from: record)

        #expect(member.serverID == "42")  // Int → String 변환
        #expect(member.name == "김철수")
        #expect(member.nickname == "철수")
        #expect(member.university == "한성대")
        #expect(member.reason == "회의 지연")
        #expect(member.requestTime == Date(timeIntervalSince1970: 1000))
        #expect(member.profileImageURL == "https://example.com/profile.png")
    }

    @Test("profileImageLink 가 nil 이면 profileImageURL 도 nil 로 매핑된다")
    func mapsRecordWithNilProfileImage() {
        let record = PendingAttendanceRecord(
            attendanceId: 1,
            memberId: "M-1",
            memberName: "김철수",
            nickname: "철수",
            profileImageLink: nil,
            schoolName: "한성대",
            status: .pendingApproval,
            reason: nil,
            requestedAt: Date(timeIntervalSince1970: 0)
        )

        let member = OperatorPendingMember(from: record)

        #expect(member.profileImageURL == nil)
    }

    @Test("매퍼 결과에 hasReason 도메인 규칙이 그대로 적용된다")
    func mappedMemberRespectsHasReasonRule() {
        let withReason = PendingAttendanceRecord(
            attendanceId: 1,
            memberId: "M-1",
            memberName: "A",
            nickname: "a",
            profileImageLink: nil,
            schoolName: "한성대",
            status: .pendingApproval,
            reason: "사유",
            requestedAt: Date(timeIntervalSince1970: 0)
        )
        let withoutReason = PendingAttendanceRecord(
            attendanceId: 2,
            memberId: "M-2",
            memberName: "B",
            nickname: "b",
            profileImageLink: nil,
            schoolName: "한성대",
            status: .pendingApproval,
            reason: nil,
            requestedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(OperatorPendingMember(from: withReason).hasReason == true)
        #expect(OperatorPendingMember(from: withoutReason).hasReason == false)
    }
}
