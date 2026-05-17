//
//  OperatorSessionStatusTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/8/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("OperatorSessionStatus — 시간 기반 상태 결정 (도메인 규칙)")
struct OperatorSessionStatusTests {

    // MARK: - Helper

    private func date(_ epoch: TimeInterval) -> Date {
        Date(timeIntervalSince1970: epoch)
    }

    // MARK: - 분기 검증

    @Test("now < startTime 이면 .beforeStart")
    func returnsBeforeStartWhenBeforeStart() {
        let start = date(1000)
        let end = date(2000)
        let now = date(500)

        let status = OperatorSessionStatus.from(startTime: start, endTime: end, now: now)

        #expect(status == .beforeStart)
    }

    @Test("startTime <= now <= endTime 이면 .inProgress")
    func returnsInProgressWhenWithinRange() {
        let start = date(1000)
        let end = date(2000)
        let now = date(1500)

        let status = OperatorSessionStatus.from(startTime: start, endTime: end, now: now)

        #expect(status == .inProgress)
    }

    @Test("now == startTime (경계) 일 때도 .inProgress")
    func boundaryStartIsInProgress() {
        let start = date(1000)
        let end = date(2000)

        let status = OperatorSessionStatus.from(startTime: start, endTime: end, now: start)

        #expect(status == .inProgress)
    }

    @Test("now == endTime (경계) 일 때도 .inProgress")
    func boundaryEndIsInProgress() {
        let start = date(1000)
        let end = date(2000)

        let status = OperatorSessionStatus.from(startTime: start, endTime: end, now: end)

        #expect(status == .inProgress)
    }

    @Test("now > endTime 이면 .ended")
    func returnsEndedWhenAfterEnd() {
        let start = date(1000)
        let end = date(2000)
        let now = date(2500)

        let status = OperatorSessionStatus.from(startTime: start, endTime: end, now: now)

        #expect(status == .ended)
    }

    // MARK: - 엣지 케이스

    @Test("startTime == endTime 인 즉시 종료 세션은 그 시점에 .inProgress, 직후 .ended")
    func zeroDurationSession() {
        let instant = date(1000)

        #expect(
            OperatorSessionStatus.from(startTime: instant, endTime: instant, now: instant)
            == .inProgress
        )
        #expect(
            OperatorSessionStatus.from(startTime: instant, endTime: instant, now: date(1001))
            == .ended
        )
    }
}
