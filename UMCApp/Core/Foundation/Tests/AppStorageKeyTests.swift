//
//  AppStorageKeyTests.swift
//  UMCFoundationTests
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import Testing
@testable import UMCFoundation

// MARK: - Fixtures

/// 이름 붙은 식별자 헬퍼 3종은 읽는 키만 다르고 해석 규칙이 같으므로 한 묶음으로 파라미터화합니다.
private struct IdentifierHelper: Sendable, CustomStringConvertible {
    let name: String
    let key: String
    let read: @Sendable (UserDefaults) -> String?

    var description: String { name }
}

private let identifierHelpers: [IdentifierHelper] = [
    IdentifierHelper(
        name: "memberIdString",
        key: AppStorageKey.memberId,
        read: { AppStorageKey.memberIdString(in: $0) }
    ),
    IdentifierHelper(
        name: "schoolIdString",
        key: AppStorageKey.schoolId,
        read: { AppStorageKey.schoolIdString(in: $0) }
    ),
    IdentifierHelper(
        name: "gisuIdString",
        key: AppStorageKey.gisuId,
        read: { AppStorageKey.gisuIdString(in: $0) }
    )
]

// MARK: - Suite: 저장 식별자 해석

@Suite("AppStorageKey — 저장 식별자 해석 (도메인 규칙)")
struct AppStorageKeyIdentifierTests {

    /// 테스트마다 고유 suite 이름으로 격리해 잔여 값/병렬 실행 간섭을 차단합니다.
    private func makeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "test.foundation.appStorageKey.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - 해석 규칙

    @Test("String 저장값을 그대로 반환한다", arguments: identifierHelpers)
    fileprivate func returnsStoredStringValue(helper: IdentifierHelper) {
        let defaults = makeDefaults("string-\(helper.name)")
        defaults.set("42", forKey: helper.key)

        #expect(helper.read(defaults) == "42")
    }

    @Test("레거시 Int 저장값은 문자열로 변환해 반환한다", arguments: identifierHelpers)
    fileprivate func returnsLegacyIntValueAsString(helper: IdentifierHelper) {
        let defaults = makeDefaults("legacyInt-\(helper.name)")
        defaults.set(7, forKey: helper.key)

        #expect(helper.read(defaults) == "7")
    }

    @Test("키가 없으면 nil 을 반환한다", arguments: identifierHelpers)
    fileprivate func returnsNilWhenKeyAbsent(helper: IdentifierHelper) {
        let defaults = makeDefaults("absent-\(helper.name)")

        #expect(helper.read(defaults) == nil)
    }

    @Test("빈 문자열은 미설정으로 취급해 nil 을 반환한다", arguments: identifierHelpers)
    fileprivate func returnsNilWhenStoredValueIsEmpty(helper: IdentifierHelper) {
        let defaults = makeDefaults("empty-\(helper.name)")
        defaults.set("", forKey: helper.key)

        #expect(helper.read(defaults) == nil)
    }

    // MARK: - 키 배선

    /// 공용 해석기로 묶은 뒤에도 각 헬퍼가 자기 키에 그대로 연결돼 있는지 고정합니다.
    @Test("헬퍼끼리 서로의 키를 읽지 않는다")
    func eachHelperReadsItsOwnKey() {
        let defaults = makeDefaults("keyWiring")
        defaults.set("100", forKey: AppStorageKey.memberId)
        defaults.set("5", forKey: AppStorageKey.schoolId)
        defaults.set("7", forKey: AppStorageKey.gisuId)

        #expect(AppStorageKey.memberIdString(in: defaults) == "100")
        #expect(AppStorageKey.schoolIdString(in: defaults) == "5")
        #expect(AppStorageKey.gisuIdString(in: defaults) == "7")
    }
}
