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
@Suite("ReceivedCardRepository — 저장/검색/삭제/카운트/upsert/계정 격리")
struct ReceivedCardRepositoryTests {

    /// 지금 로그인한 계정. 저장소가 이 값으로 모든 쿼리를 스코프한다.
    private static let owner = "100"
    /// 같은 기기를 쓰는 다른 계정.
    private static let otherOwner = "200"

    /// 컨테이너를 함께 붙잡지 않으면 인메모리 스토어가 먼저 해제돼 트랩한다 (Home 선례).
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let repository: ReceivedCardRepository

    init() throws {
        container = try ModelContainer(
            for: ReceivedCardRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // 테스트 인스턴스마다 고유 suite — 병렬 실행 간섭과 잔여 값을 차단한다.
        let suiteName = "test.businessCard.receivedCards.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Self.owner, forKey: AppStorageKey.memberId)
        repository = ReceivedCardRepository(
            modelContext: container.mainContext,
            defaults: defaults
        )
    }

    /// 로그인 계정을 갈아 끼운다 — 로그아웃 후 다른 계정으로 들어온 상황.
    private func switchAccount(to memberId: String?) {
        if let memberId {
            defaults.set(memberId, forKey: AppStorageKey.memberId)
        } else {
            defaults.removeObject(forKey: AppStorageKey.memberId)
        }
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
    private func insertRecord(
        cardID: String,
        memberId: String,
        name: String,
        owner: String = ReceivedCardRepositoryTests.owner,
        exchangedAt: Date = Date()
    ) {
        container.mainContext.insert(
            ReceivedCardRecord(
                ownerMemberId: owner,
                cardID: cardID, memberId: memberId, name: name, nickname: "\(name)닉",
                partRaw: "DESIGN", generation: "11", university: "중앙대학교",
                email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil,
                exchangedAt: exchangedAt, exchangeContext: nil
            )
        )
    }

    @Test("memberId 없는 레코드도 명함 내용으로 CloudKit 중복이 걸러진다")
    func dedupesIdentitylessRecordsByContent() async throws {
        // CloudKit 동기화가 같은 레코드를 두 벌 만든 상황. cardID는 교환마다 달라진다.
        insertRecord(cardID: "C1", memberId: "", name: "정체불명")
        insertRecord(cardID: "C2", memberId: "", name: "정체불명")
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

    // MARK: - 정체성 키 통일 (#1218)

    /// 목록에 보이는 것은 dedup 후 최신 1장뿐이라, cardID로만 지우면 같은 사람의 옛 행이
    /// 남아 다음 진입에서 되살아난다.
    @Test("같은 상대의 cardID가 여러 벌이어도 한 번 삭제로 전부 사라진다")
    func deleteRemovesEveryRecordOfSameIdentity() async throws {
        // 기기 A·B에서 각각 교환 → 같은 memberId, 다른 cardID가 CloudKit으로 합쳐진 상황.
        // 교환 시각을 벌려 둔다 — 목록에 뜨는 쪽(최신)과 숨는 쪽(과거)이 뒤집히면
        // 「보이던 한 장을 지웠는데 숨어 있던 옛 행이 올라온다」를 짚지 못한다.
        let now = Date()
        insertRecord(cardID: "C-NEW", memberId: "7", name: "상대", exchangedAt: now)
        insertRecord(
            cardID: "C-OLD", memberId: "7", name: "상대",
            exchangedAt: now.addingTimeInterval(-3600)
        )
        try container.mainContext.save()
        let visible = try #require(try await repository.fetchAll().first)
        #expect(visible.id == "C-NEW")

        try await repository.delete(id: visible.id)

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.count() == 0)
    }

    /// cardID가 교환마다 새 UUID라, 그걸 대체 키로 쓰면 같은 사람과 다시 교환할 때마다
    /// 새 행이 쌓인다 (#1196 「한 번만 저장」이 memberId 있을 때만 성립했다).
    @Test("memberId 없는 상대와 두 번 교환해도 명함첩은 1장이다")
    func reExchangeWithoutMemberIdStaysSingleCard() async throws {
        let first = makeCard(id: UUID().uuidString, name: "상대", memberId: "")
        let second = makeCard(id: UUID().uuidString, name: "상대", memberId: "")

        try await repository.save(first)
        try await repository.save(second)

        #expect(try await repository.fetchAll().count == 1)
        #expect(try await repository.count() == 1)
    }

    /// 정체성 없는 서로 다른 사람까지 뭉치면 데이터 손실이다 — 삭제도 남을 건드리면 안 된다.
    @Test("memberId 없는 다른 사람은 함께 지워지지 않는다")
    func deleteKeepsOtherIdentitylessPeople() async throws {
        insertRecord(cardID: "C1", memberId: "", name: "김하나")
        insertRecord(cardID: "C2", memberId: "", name: "박두울")
        try container.mainContext.save()

        try await repository.delete(id: "C1")

        #expect(try await repository.fetchAll().map(\.profile.name) == ["박두울"])
    }

    // MARK: - 계정 격리 (#1217)

    /// 한 기기에서 계정을 바꿨을 때 이전 사용자의 명함(이름·학교·이메일·링크)이
    /// 그대로 보이던 개인정보 노출을 막는다.
    @Test("계정을 바꾸면 목록·검색·카운트가 그 계정 명함만 보여준다")
    func switchingAccountIsolatesCardbook() async throws {
        try await repository.save(makeCard(id: "C1", name: "에이가받은사람", memberId: "1"))

        switchAccount(to: Self.otherOwner)

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.count() == 0)
        #expect(try await repository.search(query: "에이가").isEmpty)

        try await repository.save(makeCard(id: "C2", name: "비가받은사람", memberId: "2"))
        #expect(try await repository.fetchAll().map(\.profile.name) == ["비가받은사람"])
        #expect(try await repository.count() == 1)

        // 돌아오면 자기 명함은 그대로다 — 격리지 삭제가 아니다.
        switchAccount(to: Self.owner)
        #expect(try await repository.fetchAll().map(\.profile.name) == ["에이가받은사람"])
    }

    /// 다른 계정의 레코드가 upsert 대상으로 잡히면 그 행을 덮어써 남의 데이터를 파괴한다.
    @Test("같은 상대를 다른 계정이 받아도 서로 다른 레코드로 남는다")
    func sameCounterpartIsStoredPerAccount() async throws {
        try await repository.save(makeCard(id: "C1", name: "상대", memberId: "7"))

        switchAccount(to: Self.otherOwner)
        try await repository.save(makeCard(id: "C1", name: "상대", memberId: "7"))
        #expect(try await repository.count() == 1)

        switchAccount(to: Self.owner)
        #expect(try await repository.count() == 1)
    }

    /// 소유자 술어가 없으면 로그아웃 직후(세션 키가 비워진 상태) 명함첩이 그대로 열린다.
    @Test("로그인 세션이 없으면 명함첩은 비어 있고 저장·삭제는 실패한다")
    func noSessionYieldsEmptyCardbook() async throws {
        try await repository.save(makeCard(id: "C1", memberId: "1"))

        switchAccount(to: nil)

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.search(query: "상대").isEmpty)
        #expect(try await repository.count() == 0)
        await #expect(throws: AuthError.notLoggedIn) {
            try await repository.save(makeCard(id: "C2", memberId: "2"))
        }
        await #expect(throws: AuthError.notLoggedIn) {
            try await repository.delete(id: "C1")
        }
    }

    /// 소유자를 모르는 구버전 레코드(마이그레이션 기본값 `""`)는 누구의 것인지 알 수 없다.
    /// 남의 명함을 보여주느니 안 보이는 쪽이 맞다.
    @Test("소유자 없는 구버전 레코드는 어느 계정에도 잡히지 않는다")
    func legacyOwnerlessRecordsStayHidden() async throws {
        insertRecord(cardID: "OLD", memberId: "9", name: "구버전", owner: "")
        try container.mainContext.save()

        #expect(try await repository.fetchAll().isEmpty)
        #expect(try await repository.count() == 0)

        switchAccount(to: Self.otherOwner)
        #expect(try await repository.fetchAll().isEmpty)
    }

    /// 회원 탈퇴 경로. 로컬(+CloudKit) 명함첩은 계정을 지워도 기기에 남는다.
    @Test("deleteAll은 현재 계정 명함만 지운다")
    func deleteAllRemovesOnlyCurrentAccountCards() async throws {
        try await repository.save(makeCard(id: "C1", memberId: "1"))
        insertRecord(cardID: "C2", memberId: "2", name: "남의명함", owner: Self.otherOwner)
        try container.mainContext.save()

        try await repository.deleteAll()

        #expect(try await repository.fetchAll().isEmpty)

        switchAccount(to: Self.otherOwner)
        #expect(try await repository.fetchAll().map(\.profile.name) == ["남의명함"])
    }
}
