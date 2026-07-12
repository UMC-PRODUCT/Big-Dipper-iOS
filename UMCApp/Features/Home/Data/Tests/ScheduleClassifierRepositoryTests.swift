//
//  ScheduleClassifierRepositoryTests.swift
//  HomeDataTests
//
//  키워드 매칭 테이블(카테고리별 대표 키워드/미매칭 시 .general)과 `UserDefaults` 기반 캐시
//  저장/로드 roundtrip(deprecated 카테고리 필터링 포함)을 검증한다. `UserDefaults.standard`를
//  오염시키지 않도록 매 테스트마다 임시 suite를 만들어 쓰고 종료 시 제거한다.
//

import Foundation
import Testing
import UMCFoundation
@testable import HomeData

@Suite("ScheduleClassifierRepository — 키워드 분류 & 캐시 검증")
struct ScheduleClassifierRepositoryTests {

    // MARK: - 키워드 분류

    @Test(
        "카테고리별 대표 키워드가 올바르게 분류된다",
        arguments: [
            ("운영진 회의", ScheduleIconCategory.leadership),
            ("알고리즘 스터디", .study),
            ("회비 납부 안내", .fee),
            ("정기 미팅", .meeting),
            ("네트워킹 데이", .networking),
            ("해커톤 대회", .hackathon),
            ("프로젝트 개발", .project),
            ("중간 발표", .presentation),
            ("MT 워크샵", .workshop),
            ("스프린트 회고", .review),
            ("데모데이 파티", .celebration),
            ("신입생 OT", .orientation),
        ]
    )
    func classifiesRepresentativeKeywords(title: String, expected: ScheduleIconCategory) {
        let repository = ScheduleClassifierRepository(userDefaults: makeEphemeralUserDefaults())

        #expect(repository.classifyWithKeywords(title: title) == expected)
    }

    @Test("매칭되는 키워드가 없으면 .general을 반환한다")
    func unmatchedTitleReturnsGeneral() {
        let repository = ScheduleClassifierRepository(userDefaults: makeEphemeralUserDefaults())

        #expect(repository.classifyWithKeywords(title: "아무 의미 없는 제목") == .general)
    }

    // MARK: - CoreML 모델 로드

    /// staticFramework(HomeData)에서 `.mlmodel`이 `Home_HomeData.bundle`로 실제 번들링되어
    /// `Bundle.module` 경로로 로드되는지 검증한다. 이 검증이 없으면 Tuist/Xcode 업그레이드로
    /// 리소스 번들 워크어라운드가 조용히 깨져도(→ 키워드 전용으로 degrade) 테스트가 통과해
    /// 회귀를 놓친다.
    @Test("CoreML 모델이 번들 리소스에서 로드되어 실제 예측을 수행한다")
    func modelLoadsFromBundleAndPredictsNonNilCategory() {
        let repository = ScheduleClassifierRepository(userDefaults: makeEphemeralUserDefaults())

        #expect(repository.isModelLoaded == true)
        #expect(repository.classifyWithML(title: "정기 세미나 진행 안내") != nil)
    }

    // MARK: - 캐시 저장/로드

    @Test("cacheCategory로 저장한 값이 새 인스턴스에서도 로드된다 (roundtrip)")
    func cacheRoundTripsAcrossInstances() {
        withEphemeralUserDefaults { userDefaults in
            let repository = ScheduleClassifierRepository(userDefaults: userDefaults)
            repository.cacheCategory(.hackathon, for: "해커톤 대회")

            let reloaded = ScheduleClassifierRepository(userDefaults: userDefaults)
            #expect(reloaded.getCachedCategory(for: "해커톤 대회") == .hackathon)
        }
    }

    @Test("로드 시 deprecated 카테고리(testing)는 캐시에서 필터링된다")
    func loadFiltersDeprecatedCategories() throws {
        try withEphemeralUserDefaults { userDefaults in
            let seed = ["레거시 테스트": "TESTING", "정기 회의": "MEETING"]
            let data = try JSONEncoder().encode(seed)
            userDefaults.set(data, forKey: "ScheduleClassifierCache.v5")

            let repository = ScheduleClassifierRepository(userDefaults: userDefaults)

            #expect(repository.getCachedCategory(for: "레거시 테스트") == nil)
            #expect(repository.getCachedCategory(for: "정기 회의") == .meeting)
        }
    }
}

// MARK: - Helpers

private func makeEphemeralUserDefaults() -> UserDefaults {
    UserDefaults(suiteName: "ScheduleClassifierRepositoryTests.\(UUID().uuidString)")!
}

/// 임시 `UserDefaults` suite를 생성해 `body`에 전달하고, 종료 시 영구 도메인을 제거한다.
private func withEphemeralUserDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
    let suiteName = "ScheduleClassifierRepositoryTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer { userDefaults.removePersistentDomain(forName: suiteName) }
    return try body(userDefaults)
}
