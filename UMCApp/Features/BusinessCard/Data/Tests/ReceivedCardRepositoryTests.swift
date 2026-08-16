//
//  ReceivedCardRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import SwiftData
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardData

@MainActor
@Suite("ReceivedCardRepository — 저장/검색/삭제/카운트/upsert")
struct ReceivedCardRepositoryTests {

    /// 컨테이너를 함께 붙잡지 않으면 인메모리 스토어가 먼저 해제돼 트랩한다 (Home 선례).
    private let container: ModelContainer
    private let repository: ReceivedCardRepository

    init() throws {
        container = try ModelContainer(
            for: ReceivedCardRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        repository = ReceivedCardRepository(modelContext: container.mainContext)
    }

    private func makeCard(
        id: String = "CARD-1", name: String = "상대", memberId: String = "7"
    ) -> ReceivedCard {
        ReceivedCard(
            id: id,
            profile: MyCard(
                memberId: memberId, name: name, nickname: "\(name)닉",
                part: .design, generation: "11", university: "중앙대학교",
                email: nil, github: nil, blog: nil, avatarURL: nil
            ),
            exchangedAt: Date(), exchangeContext: "OT에서 교환", isConnected: false
        )
    }

    @Test("저장 후 전체 조회하면 같은 명함이 나온다")
    func saveThenFetchRoundtrip() async throws {
        try await repository.save(makeCard())

        let all = try await repository.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.profile.name == "상대")
        #expect(all.first?.profile.part == .design)
    }

    @Test("같은 memberId로 다시 저장하면 중복 없이 최신 명함으로 갱신된다")
    func upsertByMemberId() async throws {
        try await repository.save(makeCard(id: "CARD-1", name: "상대"))
        try await repository.save(makeCard(id: "CARD-2", name: "개명한상대"))

        let all = try await repository.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.profile.name == "개명한상대")
        #expect(try await repository.count() == 1)
    }

    @Test("이름·닉네임·파트·학교로 검색된다 (MP 받은명함_검색)")
    func searchMatchesFields() async throws {
        try await repository.save(makeCard(id: "C1", name: "김디자", memberId: "1"))
        try await repository.save(makeCard(id: "C2", name: "박서버", memberId: "2"))

        #expect(try await repository.search(query: "김디").count == 1)
        #expect(try await repository.search(query: "박서버닉").count == 1)
        #expect(try await repository.search(query: "중앙").count == 2)
        #expect(try await repository.search(query: "없는사람").isEmpty)
    }

    @Test("공백 검색어는 전체 목록을 돌려준다")
    func blankQueryReturnsAll() async throws {
        try await repository.save(makeCard(id: "C1", memberId: "1"))
        try await repository.save(makeCard(id: "C2", memberId: "2"))

        #expect(try await repository.search(query: "  ").count == 2)
    }

    @Test("삭제하면 목록과 카운트에서 빠진다")
    func deleteRemoves() async throws {
        try await repository.save(makeCard(id: "C1", memberId: "1"))

        try await repository.delete(id: "C1")

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.count() == 0)
    }
}
