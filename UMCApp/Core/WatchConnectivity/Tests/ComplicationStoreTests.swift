//
//  ComplicationStoreTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import Testing
@testable import CoreWatchConnectivity

/// App Group 공유 스토어와 타임라인 엔트리 생성 규칙.
///
/// 실제 App Group(`group.com.umc.product.watch`)은 서명된 앱에서만 열리므로 테스트는 임의
/// suite 이름을 주입한다. 검증 대상은 컨테이너가 아니라 **직렬화 왕복과 엔트리 규칙**이다.
@Suite("ComplicationStore — 공유 저장 · 타임라인")
final class ComplicationStoreTests {

    // MARK: - Fixture

    private let suiteName = "complication.tests.\(UUID().uuidString)"
    private let store: ComplicationStore
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    init() {
        store = ComplicationStore(suiteName: suiteName)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func minutes(_ value: Double) -> Date {
        now.addingTimeInterval(value * 60)
    }

    /// `generatedAt` 을 초 단위로 딱 떨어지게 잡는다 — 봉투 코덱이 ISO8601 이라
    /// 소수점 이하가 왕복에서 잘린다.
    private func makeSnapshot(
        nextSession: ComplicationSession? = nil,
        attendance: ComplicationAttendanceState = .upcoming
    ) -> ComplicationSnapshot {
        ComplicationSnapshot(
            isSignedIn: true,
            nextSession: nextSession,
            attendance: attendance,
            unreadPingCount: 3,
            generatedAt: now
        )
    }

    private func makeSession(window: WatchAttendanceWindow?) -> ComplicationSession {
        ComplicationSession(
            scheduleId: "1",
            name: "정기 세션",
            startsAt: minutes(-5),
            endsAt: minutes(60),
            attendanceWindow: window
        )
    }

    // MARK: - Storage

    @Test("저장한 스냅샷이 그대로 돌아온다")
    func saveLoadRoundtrip() {
        let snapshot = makeSnapshot(nextSession: makeSession(window: nil))

        store.save(snapshot)

        #expect(store.load() == snapshot)
    }

    @Test("빈 스토어는 nil 을 낸다")
    func emptyStoreLoadsNil() {
        #expect(store.load() == nil)
    }

    @Test("clear 이후에는 nil 을 낸다")
    func clearRemovesSnapshot() {
        store.save(makeSnapshot())

        store.clear()

        #expect(store.load() == nil)
    }

    // MARK: - Timeline

    @Test("엔트리는 now 로 시작해 미래 경계만 오름차순으로 잇는다")
    func timelineEntriesCoverFutureBoundaries() {
        let window = WatchAttendanceWindow(
            checkInStartAt: minutes(-10),
            onTimeEndAt: minutes(10),
            lateEndAt: minutes(20)
        )
        let snapshot = makeSnapshot(
            nextSession: makeSession(window: window),
            attendance: .awaiting
        )

        let entries = ComplicationTimeline.entries(from: snapshot, now: now)
        let dates = entries.map(\.date)

        #expect(dates.first == now)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= now })
        #expect(entries.count <= 7)
        #expect(dates == [now, minutes(10), minutes(20), minutes(60)])
        // 창이 닫히는 시각 이후의 엔트리는 창 폴백으로 결석이 되어야 한다.
        #expect(entries.last?.snapshot.attendance == .absent)
    }

    @Test("서버 확정 상태는 경계 엔트리에서도 유지된다")
    func decidedStateSurvivesProjection() {
        let window = WatchAttendanceWindow(
            checkInStartAt: minutes(-10),
            onTimeEndAt: minutes(10),
            lateEndAt: minutes(20)
        )
        let snapshot = makeSnapshot(
            nextSession: makeSession(window: window),
            attendance: .present
        )

        let entries = ComplicationTimeline.entries(from: snapshot, now: now)

        #expect(entries.allSatisfy { $0.snapshot.attendance == .present })
    }

    @Test("경계가 없으면 엔트리는 하나뿐이다")
    func timelineWithoutBoundaries() {
        let entries = ComplicationTimeline.entries(from: makeSnapshot(), now: now)

        #expect(entries.count == 1)
        #expect(entries.first?.date == now)
    }
}
