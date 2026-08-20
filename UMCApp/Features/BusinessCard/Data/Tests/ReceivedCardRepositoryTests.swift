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
                email: nil, github: nil, linkedIn: "linkedin.com/in/\(memberId)",
                blog: nil, avatarURL: nil
            ),
            exchangedAt: Date(), exchangeContext: "OT에서 교환"
        )
    }

    @Test("저장 후 전체 조회하면 같은 명함이 나온다")
    func saveThenFetchRoundtrip() async throws {
        try await repository.save(makeCard())

        let all = try await repository.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.profile.name == "상대")
        #expect(all.first?.profile.part == .design)
        #expect(all.first?.profile.linkedIn == "linkedin.com/in/7")
    }

    /// 못 읽은 파트를 `ADMIN` 으로 눌러 저장하면 **원본이 영영 사라진다.** 나중에 파싱
    /// 규칙이 늘어도 되살릴 방법이 없다. 원본 그대로 담기는지 저장·조회 왕복으로 본다.
    @Test("모르는 파트 문자열은 원본 그대로 저장되고 다시 읽힌다")
    func unknownPartSurvivesRoundtrip() async throws {
        let card = ReceivedCard(
            id: "CARD-RAW",
            profile: MyCard(
                memberId: "9", name: "상대", nickname: "닉",
                part: .admin, generation: "11", university: "중앙대학교",
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
                partRaw: "RUST"
            ),
            exchangedAt: Date(), exchangeContext: nil
        )
        try await repository.save(card)

        let restored = try #require(try await repository.fetchAll().first)

        #expect(restored.profile.partRaw == "RUST")
        #expect(restored.profile.partDisplayName == "RUST")
        #expect(restored.profile.part == .admin)
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

    /// memberId가 비는 경로: v1 페이로드(cardLink="")나 파싱 불가한 cardLink.
    /// `MyCard(payload:)`가 `linkedMemberId ?? ""`로 복원하므로 정체성이 없는 레코드가 생긴다.
    private func insertRecord(cardID: String, memberId: String, name: String) {
        container.mainContext.insert(
            ReceivedCardRecord(
                cardID: cardID, memberId: memberId, name: name, nickname: "\(name)닉",
                partRaw: "DESIGN", generation: "11", university: "중앙대학교",
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
                exchangedAt: Date(), exchangeContext: nil
            )
        )
    }

    @Test("memberId 없는 레코드도 cardID로 CloudKit 중복이 걸러진다")
    func dedupesIdentitylessRecordsByCardID() async throws {
        // CloudKit 동기화가 같은 레코드를 두 벌 만든 상황.
        insertRecord(cardID: "C1", memberId: "", name: "정체불명")
        insertRecord(cardID: "C1", memberId: "", name: "정체불명")
        try container.mainContext.save()

        #expect(try await repository.fetchAll().count == 1)
        #expect(try await repository.count() == 1)
    }

    @Test("memberId 없는 서로 다른 사람은 하나로 뭉치지 않는다")
    func keepsDistinctIdentitylessRecords() async throws {
        // 빈 memberId를 같은 키로 취급하면 서로 다른 사람이 한 명으로 사라진다.
        insertRecord(cardID: "C1", memberId: "", name: "김하나")
        insertRecord(cardID: "C2", memberId: "", name: "박두울")
        try container.mainContext.save()

        #expect(try await repository.fetchAll().count == 2)
    }

    @Test("삭제하면 목록과 카운트에서 빠진다")
    func deleteRemoves() async throws {
        try await repository.save(makeCard(id: "C1", memberId: "1"))

        try await repository.delete(id: "C1")

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.count() == 0)
    }
}
