//
//  ComplicationSnapshotTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import Testing
@testable import CoreWatchConnectivity

/// 워치페이스가 그리는 값을 뽑는 파생 규칙.
///
/// 이 파생이 무너지면 워치페이스는 「끝난 세션」이나 「색만 다른 구별 불가 상태」를 그리는데,
/// 워치페이스는 사용자가 앱을 열지 않고 보는 화면이라 잘못된 값을 정정할 기회가 없다.
@Suite("ComplicationSnapshot — WC 스냅샷 파생")
struct ComplicationSnapshotTests {

    // MARK: - Fixture

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func minutes(_ value: Double) -> Date {
        now.addingTimeInterval(value * 60)
    }

    private func makeSchedule(
        scheduleId: String,
        startsAt: Date,
        endsAt: Date,
        window: WatchAttendanceWindow? = nil,
        status: String? = nil
    ) -> WatchSchedule {
        WatchSchedule(
            scheduleId: scheduleId,
            name: "세션 \(scheduleId)",
            startsAt: startsAt,
            endsAt: endsAt,
            location: nil,
            attendanceWindow: window,
            attendanceStatus: status
        )
    }

    private func makeNotice(noticeId: String, isRead: Bool) -> WatchNotice {
        WatchNotice(
            noticeId: noticeId,
            title: "공지 \(noticeId)",
            content: "본문",
            writer: "운영진",
            postedAt: now,
            isMustRead: false,
            isAlert: false,
            isRead: isRead
        )
    }

    private func makeState(
        isSignedIn: Bool = true,
        schedules: [WatchSchedule] = [],
        notices: [WatchNotice] = []
    ) -> WatchSessionState {
        WatchSessionState(
            isSignedIn: isSignedIn,
            schedules: schedules,
            notices: notices,
            generatedAt: now
        )
    }

    private func makeSnapshot(
        window: WatchAttendanceWindow?,
        status: String?,
        now referenceDate: Date? = nil
    ) -> ComplicationSnapshot {
        let state = makeState(
            schedules: [
                makeSchedule(
                    scheduleId: "1",
                    startsAt: minutes(30),
                    endsAt: minutes(90),
                    window: window,
                    status: status
                )
            ]
        )
        return ComplicationSnapshot(state: state, now: referenceDate ?? now)
    }

    private var standardWindow: WatchAttendanceWindow {
        WatchAttendanceWindow(
            checkInStartAt: minutes(15),
            onTimeEndAt: minutes(35),
            lateEndAt: minutes(45)
        )
    }

    // MARK: - Next Session

    @Test("이미 끝난 세션은 후보에서 빠진다")
    func finishedSessionIsExcluded() {
        let state = makeState(
            schedules: [
                makeSchedule(scheduleId: "1", startsAt: minutes(-120), endsAt: minutes(-60)),
                makeSchedule(scheduleId: "2", startsAt: minutes(60), endsAt: minutes(120)),
            ]
        )

        let snapshot = ComplicationSnapshot(state: state, now: now)

        #expect(snapshot.nextSession?.scheduleId == "2")
    }

    @Test("진행 중인 세션이 미래 세션보다 우선한다")
    func inProgressSessionWins() {
        let state = makeState(
            schedules: [
                makeSchedule(scheduleId: "1", startsAt: minutes(10), endsAt: minutes(70)),
                makeSchedule(scheduleId: "2", startsAt: minutes(-10), endsAt: minutes(50)),
            ]
        )

        let snapshot = ComplicationSnapshot(state: state, now: now)

        #expect(snapshot.nextSession?.scheduleId == "2")
        #expect(snapshot.nextSession?.isInProgress(now: now) == true)
    }

    @Test("후보가 여럿이면 startsAt 이 가장 이른 것을 고른다")
    func earliestUpcomingSessionWins() {
        let state = makeState(
            schedules: [
                makeSchedule(scheduleId: "1", startsAt: minutes(180), endsAt: minutes(240)),
                makeSchedule(scheduleId: "2", startsAt: minutes(30), endsAt: minutes(90)),
                makeSchedule(scheduleId: "3", startsAt: minutes(60), endsAt: minutes(120)),
            ]
        )

        let snapshot = ComplicationSnapshot(state: state, now: now)

        #expect(snapshot.nextSession?.scheduleId == "2")
    }

    @Test("후보가 없으면 세션은 nil 이고 출석 상태는 none")
    func noCandidateYieldsNoneState() {
        let state = makeState(
            schedules: [
                makeSchedule(scheduleId: "1", startsAt: minutes(-120), endsAt: minutes(-60))
            ]
        )

        let snapshot = ComplicationSnapshot(state: state, now: now)

        #expect(snapshot.nextSession == nil)
        #expect(snapshot.attendance == .none)
    }

    // MARK: - Attendance Mapping

    @Test(
        "서버 확정 상태 매핑",
        arguments: [
            ("PRESENT", ComplicationAttendanceState.present),
            ("LATE", .late),
            ("EXCUSED", .excused),
            ("ABSENT", .absent),
        ]
    )
    func decidedStatusMapping(rawStatus: String, expected: ComplicationAttendanceState) {
        let snapshot = makeSnapshot(window: standardWindow, status: rawStatus)

        #expect(snapshot.attendance == expected)
    }

    @Test(
        "대기 계열은 전부 pending 으로 모인다",
        arguments: ["PENDING", "PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING"]
    )
    func pendingStatusMapping(rawStatus: String) {
        let snapshot = makeSnapshot(window: standardWindow, status: rawStatus)

        #expect(snapshot.attendance == .pending)
    }

    @Test("EXCUSED 는 present 로 합쳐지지 않는다")
    func excusedStaysDistinct() {
        let snapshot = makeSnapshot(window: standardWindow, status: "EXCUSED")

        #expect(snapshot.attendance == .excused)
        #expect(snapshot.attendance != .present)
    }

    @Test("모르는 상태 문자열은 창 기반 폴백으로 떨어진다")
    func unknownStatusFallsBackToWindow() {
        let snapshot = makeSnapshot(
            window: standardWindow,
            status: "SOME_FUTURE_STATUS",
            now: minutes(20)
        )

        #expect(ComplicationAttendanceState.from(rawStatus: "SOME_FUTURE_STATUS") == nil)
        #expect(snapshot.attendance == .awaiting)
    }

    // MARK: - Window Fallback

    @Test(
        "창 폴백 — 열리기 전 upcoming · 열린 뒤 awaiting · 닫힌 뒤 absent",
        arguments: [
            (0.0, ComplicationAttendanceState.upcoming),
            (20.0, .awaiting),
            (50.0, .absent),
        ]
    )
    func windowFallback(offset: Double, expected: ComplicationAttendanceState) {
        let snapshot = makeSnapshot(window: standardWindow, status: nil, now: minutes(offset))

        #expect(snapshot.attendance == expected)
    }

    @Test("출석 창이 없으면(비필수) none")
    func missingWindowYieldsNone() {
        let snapshot = makeSnapshot(window: nil, status: nil)

        #expect(snapshot.attendance == .none)
    }

    // MARK: - Ping Count

    @Test("미확인 개수는 읽지 않은 공지만 센다")
    func unreadPingCount() {
        let state = makeState(
            notices: [
                makeNotice(noticeId: "1", isRead: false),
                makeNotice(noticeId: "2", isRead: true),
                makeNotice(noticeId: "3", isRead: false),
            ]
        )

        #expect(ComplicationSnapshot(state: state, now: now).unreadPingCount == 2)
    }

    @Test("전부 읽었으면 미확인 개수는 0")
    func allReadYieldsZero() {
        let state = makeState(notices: [makeNotice(noticeId: "1", isRead: true)])

        #expect(ComplicationSnapshot(state: state, now: now).unreadPingCount == 0)
    }

    @Test("로그아웃 상태는 그대로 보존된다")
    func signedOutIsPreserved() {
        let state = makeState(isSignedIn: false)

        #expect(ComplicationSnapshot(state: state, now: now).isSignedIn == false)
    }

    // MARK: - Color-Free Channels

    @Test("심볼·라벨은 8개 상태에서 서로 겹치지 않는다")
    func stateChannelsAreDistinct() {
        let states = ComplicationAttendanceState.allCases
        let symbols = Set(states.map(\.symbolName))
        let labels = Set(states.map(\.shortLabel))

        #expect(states.allSatisfy { !$0.symbolName.isEmpty && !$0.shortLabel.isEmpty })
        #expect(symbols.count == states.count)
        #expect(labels.count == states.count)
    }

    @Test("승인 대기 링은 pending 에서만 켜진다")
    func pendingRingIsExclusive() {
        for state in ComplicationAttendanceState.allCases {
            #expect(state.hasPendingRing == (state == .pending))
        }
    }
}
