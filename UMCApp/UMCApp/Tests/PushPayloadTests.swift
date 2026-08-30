//
//  PushPayloadTests.swift
//  UMCAppTests
//

import Foundation
import Testing
@testable import UMCApp

@Suite("PushPayload — APNs userInfo 해석")
struct PushPayloadTests {

    // MARK: - Helper

    /// 서버 계약 그대로의 payload — FCM 은 `data` 맵을 `userInfo` 최상위에 평평하게 깔고,
    /// 값은 전부 String 이다. 각 필드를 `nil` 로 주면 그 키가 빠진 payload 가 된다.
    private func attendanceUserInfo(
        type: String? = "ATTENDANCE_STATUS_CHANGED",
        scheduleId: String? = "1234",
        deepLink: String? = "umc://attendance/1234"
    ) -> [AnyHashable: Any] {
        var userInfo: [String: String] = ["status": "PRESENT", "schemaVersion": "1"]
        userInfo["type"] = type
        userInfo["scheduleId"] = scheduleId
        userInfo["deepLink"] = deepLink
        return userInfo
    }

    // MARK: - Attendance

    /// 이 해석이 어긋나면 승인/반려 푸시를 받아도 출석 상태가 갱신되지 않는다.
    @Test("서버 계약 payload 를 그대로 읽는다")
    func parsesServerContract() {
        let payload = PushPayload(userInfo: attendanceUserInfo())

        #expect(payload.kind == .attendanceStatusChanged)
        #expect(payload.scheduleId == "1234")
        #expect(payload.deepLink == URL(string: "umc://attendance/1234"))
        #expect(payload.attendanceScheduleId == "1234")
    }

    /// 두 필드에 같은 값이 실려 오므로, 한쪽만 도착해도 갱신은 되어야 한다.
    @Test("scheduleId 가 없으면 딥링크에서 되짚는다")
    func fallsBackToDeepLink() {
        let payload = PushPayload(userInfo: attendanceUserInfo(scheduleId: nil))

        #expect(payload.attendanceScheduleId == "1234")
    }

    /// 일정 식별자는 정수의 String 직렬화라, 숫자가 아닌 값으로 갱신을 시도하느니
    /// 분기하지 않는 편이 안전하다.
    @Test("숫자가 아닌 딥링크는 폴백에서 걸러진다")
    func rejectsNonNumericDeepLinkFallback() {
        let payload = PushPayload(
            userInfo: attendanceUserInfo(scheduleId: nil, deepLink: "umc://attendance/abc")
        )

        #expect(payload.scheduleId == nil)
        #expect(payload.attendanceScheduleId == nil)
    }

    // MARK: - Other Kinds

    /// 모르는 종류까지 출석 갱신으로 흘리면 공지 푸시 한 통에 세션 재조회가 돈다.
    @Test("모르거나 없는 type 은 분기하지 않는다", arguments: [nil, "NOTICE"] as [String?])
    func ignoresUnknownKind(_ type: String?) {
        let payload = PushPayload(userInfo: attendanceUserInfo(type: type))

        #expect(payload.kind == nil)
        #expect(payload.attendanceScheduleId == nil)
    }

    /// 알림만 있는 기존 푸시(제목·본문뿐)가 여기서 깨지면 모든 푸시 수신이 막힌다.
    @Test("데이터가 없는 알림 payload 도 안전하게 읽는다")
    func parsesPlainNotification() {
        let payload = PushPayload(userInfo: ["title": "공지", "body": "새 공지가 있어요"])

        #expect(payload.kind == nil)
        #expect(payload.scheduleId == nil)
        #expect(payload.deepLink == nil)
        #expect(payload.attendanceScheduleId == nil)
    }
}
