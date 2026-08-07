//
//  StudyContextProviderTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 7/26/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityData

// MARK: - Suite: 스터디 컨텍스트 제공자 계약

@Suite("UserDefaultsStudyContextProvider — 기수·담당 파트 해석 (도메인 규칙)")
struct UserDefaultsStudyContextProviderTests {

    /// 테스트마다 고유 suite 이름으로 격리해 잔여 값/병렬 실행 간섭을 차단합니다.
    private func makeDefaults(_ name: String) -> UserDefaults {
        let suiteName = "test.study.context.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - 기수 식별자

    @Test("숫자로 저장된 기수도 문자열 식별자로 반환한다")
    func resolvesNumericStoredGisuId() {
        let defaults = makeDefaults("gisuId")
        defaults.set(7, forKey: AppStorageKey.gisuId)
        let context = UserDefaultsStudyContextProvider(defaults: defaults)

        #expect(context.gisuId == "7")
    }

    @Test("기수 키가 없으면 nil 을 반환한다")
    func returnsNilGisuIdWhenAbsent() {
        let defaults = makeDefaults("gisuIdAbsent")
        let context = UserDefaultsStudyContextProvider(defaults: defaults)

        #expect(context.gisuId == nil)
    }

    // MARK: - 담당 파트 정규화

    /// 스터디 조회가 받아들이는 파트 전체 집합을 고정합니다.
    ///
    /// `ADMIN` 을 제외한 7종이며, canonical ``UMCPartType`` 수렴 전후로 동일해야 합니다.
    @Test(
        "알려진 파트는 대문자로 정규화한다",
        arguments: [
            ("ios", "IOS"), ("SpringBoot", "SPRINGBOOT"), ("WEB", "WEB"),
            ("plan", "PLAN"), ("design", "DESIGN"), ("android", "ANDROID"),
            ("nodejs", "NODEJS")
        ]
    )
    func normalizesKnownPart(stored: String, expected: String) {
        let defaults = makeDefaults("part-\(stored)")
        defaults.set(stored, forKey: AppStorageKey.responsiblePart)
        let context = UserDefaultsStudyContextProvider(defaults: defaults)

        #expect(context.part == expected)
    }

    @Test(
        "미설정·빈 값·알려지지 않은 파트는 기본 파트로 대체한다",
        arguments: [String?.none, "", "UNKNOWN_PART"]
    )
    func fallsBackToDefaultPart(stored: String?) {
        // 빈 문자열은 `SyncProfileStorageUseCase` 가 프로필에 파트가 없을 때 저장하는 값이다.
        let scenario = stored.map { $0.isEmpty ? "emptyValue" : "unknown-\($0)" } ?? "absentKey"
        let defaults = makeDefaults("partFallback-\(scenario)")
        if let stored {
            defaults.set(stored, forKey: AppStorageKey.responsiblePart)
        }
        let context = UserDefaultsStudyContextProvider(defaults: defaults)

        #expect(context.part == "IOS")
    }

    /// 운영진은 기술 파트가 아니므로 스터디 파트 조회 대상이 아니다.
    ///
    /// `ADMIN` 은 `UMCPartType` 이 해석할 수 있는 **유효한** API 값이지만(미지원 값과 다름),
    /// `SyncProfileStorageUseCase` 가 운영진 프로필에서 실제로 저장하므로 여기서 명시적으로
    /// 걸러내야 한다. canonical 파서로 수렴할 때 이 제외 규칙이 유실되지 않도록 고정한다.
    @Test("운영진(ADMIN)은 유효한 파트 값이지만 스터디 조회에서는 기본 파트로 대체한다")
    func excludesAdminFromStudyPart() {
        let defaults = makeDefaults("partAdmin")
        defaults.set("ADMIN", forKey: AppStorageKey.responsiblePart)
        let context = UserDefaultsStudyContextProvider(defaults: defaults)

        #expect(UMCPartType(apiValue: "ADMIN") == .admin, "전제: ADMIN 은 파서가 아는 값")
        #expect(context.part == "IOS")
    }
}
