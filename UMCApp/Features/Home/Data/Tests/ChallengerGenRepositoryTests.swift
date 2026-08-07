//
//  ChallengerGenRepositoryTests.swift
//  HomeDataTests
//
//  인메모리 `ModelContainer`로 (gen, gisuId) 매핑의 저장/조회 왕복, 같은 gen 재저장 시 upsert,
//  입력에 없는 기존 gen pruning, gen 오름차순 정렬(사전순이 아닌 수치 기준)을 검증한다.
//

import Foundation
import SwiftData
import Testing
@testable import HomeData

@MainActor
@Suite("ChallengerGenRepository — 기수 매핑 upsert/pruning/정렬 검증")
struct ChallengerGenRepositoryTests {

    /// `ModelContext`는 컨테이너를 소유하지 않으므로, 컨테이너를 함께 붙잡아 두지 않으면
    /// 인메모리 스토어가 먼저 해제돼 이후 fetch/save가 트랩한다.
    private let container: ModelContainer
    private let repository: ChallengerGenRepository

    init() throws {
        container = try ModelContainer(
            for: GenerationMappingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        repository = ChallengerGenRepository(modelContext: container.mainContext)
    }

    @Test("저장한 매핑을 그대로 조회한다")
    func replaceThenFetchRoundtrip() throws {
        try repository.replaceMappings([(gen: "11", gisuId: "101")])

        let pairs = try repository.fetchGenGisuIdPairs()
        #expect(pairs.count == 1)
        #expect(pairs.first?.gen == "11")
        #expect(pairs.first?.gisuId == "101")
    }

    @Test("같은 gen을 다시 저장하면 중복 생성 없이 gisuId만 갱신된다")
    func replaceUpdatesExistingGen() throws {
        try repository.replaceMappings([(gen: "11", gisuId: "101")])
        try repository.replaceMappings([(gen: "11", gisuId: "202")])

        let pairs = try repository.fetchGenGisuIdPairs()
        #expect(pairs.count == 1)
        #expect(pairs.first?.gisuId == "202")
    }

    @Test("입력에 없는 기존 기수는 삭제된다")
    func replacePrunesMissingGens() throws {
        try repository.replaceMappings([(gen: "9", gisuId: "9"), (gen: "10", gisuId: "10")])
        try repository.replaceMappings([(gen: "10", gisuId: "10")])

        #expect(try repository.fetchGenGisuIdPairs().map(\.gen) == ["10"])
    }

    @Test("조회 결과는 사전순이 아닌 기수 오름차순으로 정렬된다")
    func fetchSortsByGenNumerically() throws {
        try repository.replaceMappings([
            (gen: "10", gisuId: "10"),
            (gen: "9", gisuId: "9"),
            (gen: "11", gisuId: "11"),
        ])

        #expect(try repository.fetchGenGisuIdPairs().map(\.gen) == ["9", "10", "11"])
    }
}
