//
//  UserDefaultsCurrentUserIdProviderTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Suite: 현재 사용자 식별자 어댑터 계약

@Suite("UserDefaultsCurrentUserIdProvider — 저장된 멤버 ID 해석 (도메인 규칙)")
struct UserDefaultsCurrentUserIdProviderTests {

    /// 테스트마다 고유 suite 이름으로 격리해 잔여 값/병렬 실행 간섭을 차단합니다.
    private func makeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "test.activity.currentUserId.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - 식별자 반환

    @Test("String 저장값을 변환 없이 UserID 로 반환한다")
    func returnsStoredStringIdentifier() async throws {
        let defaults = makeDefaults("storedString")
        defaults.set("42", forKey: AppStorageKey.memberId)
        let provider = UserDefaultsCurrentUserIdProvider(defaults: defaults)

        let userId = try await provider.fetchCurrentUserId()

        #expect(userId == UserID(value: "42"))
    }

    /// 레거시 `Int` 로 저장된 값도 문자열 식별자로 나오는지 확인합니다.
    /// 내부적으로 어느 분기가 처리하든, 호출부가 보는 계약은 "숫자로 저장돼도 String 이 나온다" 입니다.
    @Test("숫자로 저장된 식별자도 String UserID 로 반환한다")
    func returnsNumericStoredIdentifierAsString() async throws {
        let defaults = makeDefaults("numericStored")
        defaults.set(7, forKey: AppStorageKey.memberId)
        let provider = UserDefaultsCurrentUserIdProvider(defaults: defaults)

        let userId = try await provider.fetchCurrentUserId()

        #expect(userId == UserID(value: "7"))
    }

    // MARK: - 세션 미성립

    /// 키 부재와 빈 문자열 모두 "식별자 없음" 으로 수렴하는지 확인합니다.
    /// `UserDefaults.string(forKey:)` 는 저장된 숫자를 문자열로 강제 변환하므로,
    /// 이 두 입력이 실제 nil 분기에 도달하는 유일한 경로입니다.
    @Test(
        "식별자가 없으면 세션 미성립으로 AuthError.notLoggedIn 을 던진다",
        arguments: [String?.none, ""]
    )
    func throwsNotLoggedInWhenIdentifierMissing(stored: String?) async throws {
        let scenario = stored == nil ? "absentKey" : "emptyString"
        let defaults = makeDefaults("missing-\(scenario)")
        if let stored {
            defaults.set(stored, forKey: AppStorageKey.memberId)
        }
        let provider = UserDefaultsCurrentUserIdProvider(defaults: defaults)

        await #expect(throws: AuthError.notLoggedIn) {
            _ = try await provider.fetchCurrentUserId()
        }
    }
}
