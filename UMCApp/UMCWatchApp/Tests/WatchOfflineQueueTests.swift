import Foundation
import Testing
@testable import UMCWatchApp

@Suite("WatchOfflineQueueWindow — 3시간 유효창 경계")
struct WatchOfflineQueueTests {

    private static let measuredAt = Date(timeIntervalSince1970: 0)

    // MARK: - Test

    @Test("경과 0분 — 유효 시간 전체가 남는다")
    func noElapsedTimeKeepsFullValidity() {
        let now = Self.measuredAt
        let state = WatchOfflineQueueWindow.state(measuredAt: Self.measuredAt, now: now)

        #expect(state == .waiting(remaining: WatchOfflineQueueWindow.validity))
    }

    @Test("경과 179분 — 아직 유효하다(1분 남음)")
    func elapsed179MinutesIsStillWaiting() {
        let now = Self.measuredAt.addingTimeInterval(179 * 60)
        let state = WatchOfflineQueueWindow.state(measuredAt: Self.measuredAt, now: now)

        #expect(state == .waiting(remaining: 60))
    }

    @Test("경과 180분(정확히 3시간) — 만료로 판정한다")
    func elapsedExactlyThreeHoursExpires() {
        let now = Self.measuredAt.addingTimeInterval(180 * 60)
        let state = WatchOfflineQueueWindow.state(measuredAt: Self.measuredAt, now: now)

        #expect(state == .expired)
    }

    @Test("경과 181분 — 만료로 판정한다")
    func elapsed181MinutesExpires() {
        let now = Self.measuredAt.addingTimeInterval(181 * 60)
        let state = WatchOfflineQueueWindow.state(measuredAt: Self.measuredAt, now: now)

        #expect(state == .expired)
    }

    @Test("측정 시각이 미래(시계 오차)면 유효 시간 전체가 남는다")
    func futureMeasuredAtKeepsFullValidity() {
        let now = Self.measuredAt
        let future = Self.measuredAt.addingTimeInterval(60)
        let state = WatchOfflineQueueWindow.state(measuredAt: future, now: now)

        #expect(state == .waiting(remaining: WatchOfflineQueueWindow.validity))
    }

    @Test("waiting 은 offlineQueued, expired 는 offlineQueueExpired 로 매핑된다")
    func stateMapsToMatchingReason() {
        #expect(WatchOfflineQueueState.waiting(remaining: 60).reason == .offlineQueued)
        #expect(WatchOfflineQueueState.expired.reason == .offlineQueueExpired)
    }
}
