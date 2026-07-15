//
//  RefreshCoalescerTests.swift
//  MaintenanceDataTests
//
//  Created by euijjang97 on 7/10/26.
//

import Testing
@testable import MaintenanceData

@Suite("RefreshCoalescer — 짧은 간격 내 중복 실행 방지")
struct RefreshCoalescerTests {

    @Test("coalesce window 이내에 순차 호출하면 한 번만 실행한다")
    func coalescesSequentialCallsWithinWindow() async {
        let coalescer = RefreshCoalescer(coalesceWindow: 5)
        let counter = Counter()

        await coalescer.run { await counter.increment() }
        await coalescer.run { await counter.increment() }

        #expect(await counter.value == 1)
    }

    @Test("동시에 호출해도 실행 중인 작업 하나만 공유한다")
    func coalescesConcurrentCalls() async {
        let coalescer = RefreshCoalescer(coalesceWindow: 5)
        let counter = Counter()

        async let first: Void = coalescer.run { await counter.increment() }
        async let second: Void = coalescer.run { await counter.increment() }
        _ = await (first, second)

        #expect(await counter.value == 1)
    }

    @Test("coalesce window가 지나면 다시 실행한다")
    func reRunsAfterWindowExpires() async {
        let coalescer = RefreshCoalescer(coalesceWindow: 0)
        let counter = Counter()

        await coalescer.run { await counter.increment() }
        await coalescer.run { await counter.increment() }

        #expect(await counter.value == 2)
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
