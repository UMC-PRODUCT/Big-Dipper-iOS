//
//  ReviewRequestPolicyTests.swift
//  UMCFoundationTests
//
//  Created by JEONG on 7/30/26.
//

import Foundation
import Testing
@testable import UMCFoundation

// MARK: - Helpers

private func makeIsolatedUserDefaults() -> UserDefaults {
    let suiteName = "ReviewRequestPolicyTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

// MARK: - Tests

@Suite("ReviewRequestPolicy — 4주 간격 리뷰 요청 판정")
struct ReviewRequestPolicyTests {

    @Test("최초 호출은 요청을 허용하고 시각을 기록한다")
    func firstCallIsDueAndRecordsDate() {
        let userDefaults = makeIsolatedUserDefaults()
        let policy = ReviewRequestPolicy(userDefaults: userDefaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(policy.markRequestedIfDue(now: now))
        #expect(
            userDefaults.object(forKey: AppStorageKey.lastReviewRequestDate) as? Date == now
        )
    }

    @Test("4주 경과 직전(1초 부족)에는 요청을 차단한다")
    func blocksJustBeforeInterval() {
        let userDefaults = makeIsolatedUserDefaults()
        let policy = ReviewRequestPolicy(userDefaults: userDefaults)
        let firstRequestedAt = Date(timeIntervalSince1970: 1_800_000_000)
        _ = policy.markRequestedIfDue(now: firstRequestedAt)

        let justBefore = firstRequestedAt
            .addingTimeInterval(ReviewRequestPolicy.defaultMinimumInterval - 1)

        #expect(policy.markRequestedIfDue(now: justBefore) == false)
        #expect(
            userDefaults.object(forKey: AppStorageKey.lastReviewRequestDate) as? Date
                == firstRequestedAt
        )
    }

    @Test("4주가 정확히 경과하면 요청을 허용하고 시각을 갱신한다")
    func allowsExactlyAtInterval() {
        let userDefaults = makeIsolatedUserDefaults()
        let policy = ReviewRequestPolicy(userDefaults: userDefaults)
        let firstRequestedAt = Date(timeIntervalSince1970: 1_800_000_000)
        _ = policy.markRequestedIfDue(now: firstRequestedAt)

        let fourWeeksLater = firstRequestedAt
            .addingTimeInterval(ReviewRequestPolicy.defaultMinimumInterval)

        #expect(policy.markRequestedIfDue(now: fourWeeksLater))
        #expect(
            userDefaults.object(forKey: AppStorageKey.lastReviewRequestDate) as? Date
                == fourWeeksLater
        )
    }

    @Test("기본 최소 간격은 4주(28일)다")
    func defaultIntervalIsFourWeeks() {
        #expect(ReviewRequestPolicy.defaultMinimumInterval == 60 * 60 * 24 * 28)
    }

    @Test("최소 간격을 주입하면 해당 간격으로 판정한다")
    func respectsInjectedInterval() {
        let userDefaults = makeIsolatedUserDefaults()
        let policy = ReviewRequestPolicy(userDefaults: userDefaults, minimumInterval: 60)
        let firstRequestedAt = Date(timeIntervalSince1970: 1_800_000_000)
        _ = policy.markRequestedIfDue(now: firstRequestedAt)

        #expect(policy.markRequestedIfDue(now: firstRequestedAt.addingTimeInterval(59)) == false)
        #expect(policy.markRequestedIfDue(now: firstRequestedAt.addingTimeInterval(60)))
    }

    @Test("리뷰 요청 시각 키는 세션 스코프에 포함되지 않는다")
    func reviewDateKeyIsNotSessionScoped() {
        #expect(
            AppStorageKey.sessionScopedKeys.contains(AppStorageKey.lastReviewRequestDate) == false
        )
    }
}
