//
//  AttendanceBadgeStatusTests.swift
//  CoreUIComponentsTests
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI
import Testing
@testable import CoreUIComponents

@Suite("AttendanceBadgeStatus — 출석 상태 → 색상/문구 매핑")
struct AttendanceBadgeStatusTests {

    // MARK: - badgeText

    @Test(
        "상태별 짧은 배지 텍스트가 정확히 매핑된다",
        arguments: [
            (AttendanceBadgeStatus.presentPending, "출석 승인 대기"),
            (.latePending, "지각 승인 대기"),
            (.excusedPending, "사유 승인 대기"),
            (.present, "출석"),
            (.late, "지각"),
            (.absent, "결석"),
            (.excused, "사유 결석"),
            (.pending, "출석 전"),
            (.unknown, "알 수 없음")
        ]
    )
    func badgeTextMapping(status: AttendanceBadgeStatus, expected: String) {
        #expect(status.badgeText == expected)
    }

    // MARK: - accessibilityText

    @Test("unknown 상태의 접근성 문구는 '상태 미지정' 이다")
    func unknownAccessibilityTextIsUnspecified() {
        #expect(AttendanceBadgeStatus.unknown.accessibilityText == "상태 미지정")
    }

    @Test(
        "unknown 이 아닌 상태의 접근성 문구는 badgeText 와 동일하다",
        arguments: AttendanceBadgeStatus.allCases.filter { $0 != .unknown }
    )
    func nonUnknownAccessibilityTextEqualsBadgeText(status: AttendanceBadgeStatus) {
        #expect(status.accessibilityText == status.badgeText)
    }

    // MARK: - tintColor

    @Test(
        "출석/사유 결석은 초록 tint 를 사용한다",
        arguments: [AttendanceBadgeStatus.present, .excused]
    )
    func presentAndExcusedUseGreenTint(status: AttendanceBadgeStatus) {
        #expect(status.tintColor == .green500)
    }

    @Test("지각은 주황 tint 를 사용한다")
    func lateUsesOrangeTint() {
        #expect(AttendanceBadgeStatus.late.tintColor == .orange500)
    }

    @Test("결석은 빨강 tint 를 사용한다")
    func absentUsesRedTint() {
        #expect(AttendanceBadgeStatus.absent.tintColor == .red500)
    }

    @Test(
        "승인 대기 상태는 노랑 tint 를 사용한다",
        arguments: [AttendanceBadgeStatus.presentPending, .latePending, .excusedPending]
    )
    func pendingStatusesUseYellowTint(status: AttendanceBadgeStatus) {
        #expect(status.tintColor == .yellow500)
    }

    @Test(
        "출석 전/unknown 은 회색 tint 를 사용한다",
        arguments: [AttendanceBadgeStatus.pending, .unknown]
    )
    func pendingAndUnknownUseGreyTint(status: AttendanceBadgeStatus) {
        #expect(status.tintColor == .grey500)
    }

    // MARK: - foregroundColor

    @Test(
        "출석/사유 결석은 초록 전경색을 사용한다",
        arguments: [AttendanceBadgeStatus.present, .excused]
    )
    func presentAndExcusedUseGreenForeground(status: AttendanceBadgeStatus) {
        #expect(status.foregroundColor == .green500)
    }

    @Test("결석은 빨강 전경색을 사용한다")
    func absentUsesRedForeground() {
        #expect(AttendanceBadgeStatus.absent.foregroundColor == .red500)
    }

    @Test(
        "지각과 승인 대기 상태는 주황 전경색을 사용한다",
        arguments: [AttendanceBadgeStatus.late, .presentPending, .latePending, .excusedPending]
    )
    func lateAndPendingStatusesUseOrangeForeground(status: AttendanceBadgeStatus) {
        #expect(status.foregroundColor == .orange500)
    }

    @Test(
        "출석 전/unknown 은 회색 전경색을 사용한다",
        arguments: [AttendanceBadgeStatus.pending, .unknown]
    )
    func pendingAndUnknownUseGreyForeground(status: AttendanceBadgeStatus) {
        #expect(status.foregroundColor == .grey600)
    }
}
