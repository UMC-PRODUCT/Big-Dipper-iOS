//
//  AttendanceStatusTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/8/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("AttendanceStatus — 서버 응답 매핑 (도메인 규칙)")
struct AttendanceStatusTests {

    // MARK: - 직접 매핑

    @Test(
        "확정 상태 문자열 매핑",
        arguments: [
            ("PRESENT", AttendanceStatus.present),
            ("EXCUSED", .present),     // 사유 인정 = 출석 처리
            ("LATE",    .late),
            ("ABSENT",  .absent),
            ("PENDING", .beforeAttendance)
        ]
    )
    func mapsKnownStatuses(serverStatus: String, expected: AttendanceStatus) {
        let result = AttendanceStatus(serverStatus: serverStatus)

        #expect(result == expected)
    }

    // MARK: - PENDING 접미사 분기

    @Test(
        "명시적인 _PENDING 접미사는 .pendingApproval 로 매핑된다",
        arguments: [
            "PRESENT_PENDING",
            "LATE_PENDING",
            "EXCUSED_PENDING"
        ]
    )
    func mapsExplicitPendingSuffixes(serverStatus: String) {
        let result = AttendanceStatus(serverStatus: serverStatus)

        #expect(result == .pendingApproval)
    }

    @Test("알 수 없는 상태라도 _PENDING 으로 끝나면 .pendingApproval 로 매핑된다")
    func mapsUnknownPendingSuffixToPendingApproval() {
        // 서버에 새로운 PENDING 변형이 추가돼도 안전하게 흡수
        let result = AttendanceStatus(serverStatus: "FUTURE_NEW_TYPE_PENDING")

        #expect(result == .pendingApproval)
    }

    // MARK: - Fallback

    @Test("완전히 알 수 없는 상태는 .beforeAttendance 로 fallback 된다")
    func unknownStatusFallsBackToBeforeAttendance() {
        let result = AttendanceStatus(serverStatus: "TOTALLY_UNKNOWN")

        #expect(result == .beforeAttendance)
    }

    @Test("빈 문자열도 .beforeAttendance 로 fallback 된다")
    func emptyStringFallsBack() {
        let result = AttendanceStatus(serverStatus: "")

        #expect(result == .beforeAttendance)
    }

    // MARK: - 대소문자 민감도 (현재 구현은 대소문자 구분)

    @Test("소문자 'present' 는 매칭되지 않고 fallback 된다 — 서버는 대문자만 보낸다는 계약")
    func lowercasedDoesNotMatch() {
        let result = AttendanceStatus(serverStatus: "present")

        #expect(result == .beforeAttendance)
    }
}
