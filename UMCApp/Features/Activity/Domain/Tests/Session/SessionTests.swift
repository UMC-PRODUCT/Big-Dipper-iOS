//
//  SessionTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

@MainActor
@Suite("Session — 출석 상태 전이 (도메인 규칙)")
struct SessionTests {

    // MARK: - Helper

    private func makeInfo(
        sessionId: String = "S-1",
        week: Int = 1
    ) -> SessionInfo {
        SessionInfo(
            sessionId: SessionID(value: sessionId),
            iconName: "calendar.badge",
            title: "1주차 OT",
            week: week,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 37.5, longitude: 127.0)
        )
    }

    private func makeSession(
        sessionId: String = "S-1",
        initialAttendance: Attendance? = nil
    ) -> Session {
        Session(info: makeInfo(sessionId: sessionId), initialAttendance: initialAttendance)
    }

    private func makeAttendance(
        sessionId: String = "S-1",
        status: AttendanceStatus = .beforeAttendance
    ) -> Attendance {
        Attendance(
            sessionId: SessionID(value: sessionId),
            userId: UserID(value: "U-1"),
            type: .gps,
            status: status
        )
    }

    // MARK: - Init

    @Test("init 시 id 는 info.sessionId 와 동일하다")
    func initSetsIDFromInfo() {
        let session = makeSession(sessionId: "S-42")

        #expect(session.id == SessionID(value: "S-42"))
    }

    @Test("initialAttendance 가 주어지면 loadable 이 .loaded 로 시작한다")
    func initialAttendanceSetsLoaded() {
        let attendance = makeAttendance(status: .present)
        let session = makeSession(initialAttendance: attendance)

        #expect(session.attendance == attendance)
        #expect(session.attendanceStatus == .present)
    }

    @Test("initialAttendance 가 없으면 loadable 은 .idle 이다")
    func defaultLoadableIsIdle() {
        let session = makeSession()

        #expect(session.attendance == nil)
        #expect(session.attendanceStatus == .beforeAttendance)
    }

    // MARK: - attendanceStatus

    @Test("hasSubmitted=true && loaded(beforeAttendance) → pendingApproval")
    func hasSubmittedMapsToPendingApproval() {
        let session = makeSession(initialAttendance: makeAttendance(status: .beforeAttendance))
        session.markSubmitted()

        #expect(session.attendanceStatus == .pendingApproval)
    }

    @Test("loaded(present) 는 그대로 present 를 반환한다")
    func loadedPresentReturnsPresent() {
        let session = makeSession(initialAttendance: makeAttendance(status: .present))

        #expect(session.attendanceStatus == .present)
    }

    // MARK: - canRequestAttendance

    @Test("정시 + 지오펜스 내부 + 권한 허용 + 미제출 + 비로딩 → true")
    func canRequestWhenAllConditionsMet() {
        let session = makeSession()

        let result = session.canRequestAttendance(
            timeWindow: .onTime,
            isInsideGeofence: true,
            isLocationAuthorized: true
        )

        #expect(result == true)
    }

    @Test(
        "tooEarly/lateWindow/expired 는 모두 false",
        arguments: [AttendanceTimeWindow.tooEarly, .lateWindow, .expired]
    )
    func cannotRequestWhenNotOnTime(timeWindow: AttendanceTimeWindow) {
        let session = makeSession()

        let result = session.canRequestAttendance(
            timeWindow: timeWindow,
            isInsideGeofence: true,
            isLocationAuthorized: true
        )

        #expect(result == false)
    }

    @Test("지오펜스 밖이면 false")
    func cannotRequestWhenOutsideGeofence() {
        let session = makeSession()

        let result = session.canRequestAttendance(
            timeWindow: .onTime,
            isInsideGeofence: false,
            isLocationAuthorized: true
        )

        #expect(result == false)
    }

    @Test("위치 권한 미허용이면 false")
    func cannotRequestWhenLocationNotAuthorized() {
        let session = makeSession()

        let result = session.canRequestAttendance(
            timeWindow: .onTime,
            isInsideGeofence: true,
            isLocationAuthorized: false
        )

        #expect(result == false)
    }

    @Test("이미 제출했으면 false")
    func cannotRequestWhenAlreadySubmitted() {
        let session = makeSession()
        session.markSubmitted()

        let result = session.canRequestAttendance(
            timeWindow: .onTime,
            isInsideGeofence: true,
            isLocationAuthorized: true
        )

        #expect(result == false)
    }

    @Test("로딩 중이면 false")
    func cannotRequestWhenLoading() {
        let session = makeSession()
        session.updateState(.loading)

        let result = session.canRequestAttendance(
            timeWindow: .onTime,
            isInsideGeofence: true,
            isLocationAuthorized: true
        )

        #expect(result == false)
    }

    // MARK: - canSubmitReason

    @Test("미제출 + 비로딩 + beforeAttendance → 사유 제출 가능")
    func canSubmitReasonWhenIdle() {
        let session = makeSession()

        #expect(session.canSubmitReason() == true)
    }

    @Test("이미 제출했으면 사유 제출 불가")
    func cannotSubmitReasonWhenSubmitted() {
        let session = makeSession()
        session.markSubmitted()

        #expect(session.canSubmitReason() == false)
    }

    @Test("loaded(present) 상태면 사유 제출 불가")
    func cannotSubmitReasonWhenAlreadyPresent() {
        let session = makeSession(initialAttendance: makeAttendance(status: .present))

        #expect(session.canSubmitReason() == false)
    }

    // MARK: - isSuccess / isAttendanceAvailable

    @Test("hasSubmitted=true 이면 isSuccess=true")
    func isSuccessWhenSubmitted() {
        let session = makeSession()
        session.markSubmitted()

        #expect(session.isSuccess == true)
    }

    @Test("loaded(present) 면 isSuccess=true")
    func isSuccessWhenPresent() {
        let session = makeSession(initialAttendance: makeAttendance(status: .present))

        #expect(session.isSuccess == true)
    }

    @Test("idle 상태면 isAttendanceAvailable=true (beforeAttendance)")
    func isAvailableWhenIdle() {
        let session = makeSession()

        #expect(session.isAttendanceAvailable == true)
    }

    @Test("loaded(present) 상태면 isAttendanceAvailable=false")
    func isNotAvailableWhenPresent() {
        let session = makeSession(initialAttendance: makeAttendance(status: .present))

        #expect(session.isAttendanceAvailable == false)
    }

    // MARK: - updateStatusFromPolling

    @Test("idle 상태에서 서버가 present 통보 → loaded(present) 로 갱신")
    func pollingFromIdleToPresent() {
        let session = makeSession()

        session.updateStatusFromPolling(.present, userId: UserID(value: "U-1"))

        #expect(session.attendance?.status == .present)
        #expect(session.attendanceStatus == .present)
    }

    @Test("loaded(present) 상태에서 동일한 present 통보 → mutation 발생 안함")
    func pollingSameStatusKeepsAttendanceUnchanged() {
        let initial = makeAttendance(status: .present)
        let session = makeSession(initialAttendance: initial)

        session.updateStatusFromPolling(.present, userId: UserID(value: "U-1"))

        // 같은 상태면 attendance 객체가 그대로 유지됨
        #expect(session.attendance?.id == initial.id)
    }

    @Test("최종 확정 상태(present/late/absent) 통보 시 hasSubmitted 가 리셋된다")
    func pollingFinalStatusResetsHasSubmitted() {
        let session = makeSession()
        session.markSubmitted()

        session.updateStatusFromPolling(.present, userId: UserID(value: "U-1"))

        #expect(session.hasSubmitted == false)
    }

    @Test("pendingApproval 통보 시 hasSubmitted 는 유지된다")
    func pollingPendingApprovalKeepsHasSubmitted() {
        let session = makeSession()
        session.markSubmitted()

        session.updateStatusFromPolling(.pendingApproval, userId: UserID(value: "U-1"))

        #expect(session.hasSubmitted == true)
    }

    // MARK: - buttonTitle

    @Test("로딩 중이면 '출석 처리 중...'")
    func buttonTitleWhenLoading() {
        let session = makeSession()
        session.updateState(.loading)

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .onTime
        )

        #expect(title == "출석 처리 중...")
    }

    @Test("정시 + 권한 + 지오펜스 내부 → '현 위치로 출석체크'")
    func buttonTitleAllReady() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .onTime
        )

        #expect(title == "현 위치로 출석체크")
    }

    @Test("정시 + 권한 + 지오펜스 밖 → '출석 범위 밖'")
    func buttonTitleOutsideGeofence() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: false,
            timeWindow: .onTime
        )

        #expect(title == "출석 범위 밖")
    }

    @Test("정시 + 권한 미허용 → '위치 권한 필요'")
    func buttonTitleLocationNotAuthorized() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: false,
            isInsideGeofence: true,
            timeWindow: .onTime
        )

        #expect(title == "위치 권한 필요")
    }

    @Test("출석 시간 전이면 '아직 출석 시간이 아닙니다' (다른 조건과 무관)")
    func buttonTitleTooEarly() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .tooEarly
        )

        #expect(title == "아직 출석 시간이 아닙니다")
    }

    @Test("지각 시간대면 '지각 - 사유를 제출하세요'")
    func buttonTitleLateWindow() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .lateWindow
        )

        #expect(title == "지각 - 사유를 제출하세요")
    }

    @Test("출석 마감되면 '출석 마감됨'")
    func buttonTitleExpired() {
        let session = makeSession()

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .expired
        )

        #expect(title == "출석 마감됨")
    }

    @Test("승인 대기 상태면 다른 입력과 무관하게 '승인 대기 중'")
    func buttonTitlePendingApproval() {
        // pendingApproval 매핑 조건: loaded(beforeAttendance) + hasSubmitted=true
        let initial = makeAttendance(status: .beforeAttendance)
        let session = makeSession(initialAttendance: initial)
        session.markSubmitted()

        let title = session.buttonTitle(
            isLocationAuthorized: false,
            isInsideGeofence: false,
            timeWindow: .expired
        )

        #expect(title == "승인 대기 중")
    }

    @Test("최종 확정(present) 상태면 status displayText 가 그대로 노출된다")
    func buttonTitleFinalPresent() {
        let attendance = makeAttendance(status: .present)
        let session = makeSession(initialAttendance: attendance)

        let title = session.buttonTitle(
            isLocationAuthorized: true,
            isInsideGeofence: true,
            timeWindow: .onTime
        )

        #expect(title == AttendanceStatus.present.displayText)
    }

    @Test("최종 확정(absent) 상태면 status displayText 가 그대로 노출된다")
    func buttonTitleFinalAbsent() {
        let attendance = makeAttendance(status: .absent)
        let session = makeSession(initialAttendance: attendance)

        let title = session.buttonTitle(
            isLocationAuthorized: false,
            isInsideGeofence: false,
            timeWindow: .expired
        )

        #expect(title == AttendanceStatus.absent.displayText)
    }
}
