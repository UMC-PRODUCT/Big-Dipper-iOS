//
//  ReviewRequestPolicy.swift
//  UMCFoundation
//
//  Created by JEONG on 7/30/26.
//

import Foundation

/// 앱스토어 리뷰 요청 노출 빈도를 제한하는 정책.
///
/// `StoreKit`의 `requestReview`는 시스템이 자체적으로 표시 횟수를 제한하지만, 앱 쪽에서도
/// 최소 간격을 둬야 홈 진입마다 요청이 소모되지 않는다. 마지막 요청 시각을 `UserDefaults`에
/// 기록해 4주 이내 재요청을 차단한다.
public struct ReviewRequestPolicy {

    // MARK: - Property

    /// 기본 최소 요청 간격 (4주)
    public static let defaultMinimumInterval: TimeInterval = 60 * 60 * 24 * 28

    private let userDefaults: UserDefaults
    private let minimumInterval: TimeInterval

    // MARK: - Init

    /// - Parameters:
    ///   - userDefaults: 마지막 요청 시각을 보관할 저장소 (테스트에서 격리 suite 주입)
    ///   - minimumInterval: 재요청을 허용하기까지의 최소 경과 시간
    public init(
        userDefaults: UserDefaults = .standard,
        minimumInterval: TimeInterval = ReviewRequestPolicy.defaultMinimumInterval
    ) {
        self.userDefaults = userDefaults
        self.minimumInterval = minimumInterval
    }

    // MARK: - Function

    /// 리뷰 요청 가능 시점이면 요청 시각을 기록하고 `true`를 반환합니다.
    ///
    /// 판정과 기록을 한 번에 수행하므로, 호출부는 반환값이 `true`일 때만 실제 요청을
    /// 트리거하면 된다.
    ///
    /// - Parameter now: 현재 시각 (테스트 주입용)
    /// - Returns: 리뷰를 요청해야 하면 `true`
    public func markRequestedIfDue(now: Date = .now) -> Bool {
        let lastRequestedAt = userDefaults.object(
            forKey: AppStorageKey.lastReviewRequestDate
        ) as? Date

        if let lastRequestedAt, now.timeIntervalSince(lastRequestedAt) < minimumInterval {
            return false
        }

        userDefaults.set(now, forKey: AppStorageKey.lastReviewRequestDate)
        return true
    }
}
