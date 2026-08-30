//
//  ReceivedCardsViewModelTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/18/26.
//

import Foundation
import Testing
import UMCFoundation
import BusinessCardDomain
@testable import BusinessCardPresentation

@MainActor
@Suite("ReceivedCardsViewModel — 명함첩 로드·검색")
struct ReceivedCardsViewModelTests {

    // MARK: - Load

    @Test("로드하면 목록이 loaded 가 된다")
    func loadSucceeds() async {
        let fetch = StubFetchReceivedCards(result: [makeCard(id: "1", name: "상대")])
        let sut = makeSUT(fetch: fetch)

        await sut.load()

        #expect(sut.cards.value?.count == 1)
        #expect(fetch.lastQuery == nil)
    }

    @Test("로드가 실패하면 failed 가 된다")
    func loadFailure() async {
        let sut = makeSUT(fetch: StubFetchReceivedCards(error: StubError.boom))

        await sut.load()

        #expect(sut.cards.error != nil)
    }

    /// 상세에서 돌아왔을 때 쓰는 경로다. `.loading` 을 거치면 스켈레톤이 깜빡이고
    /// 스크롤이 튄다 — 이미 답이 떠 있는 화면에서는 그게 더 손해다.
    @Test("조용한 갱신은 목록을 비우지 않고 최신값으로 바꾼다")
    func refreshKeepsListVisible() async {
        let fetch = StubFetchReceivedCards(result: [makeCard(id: "1", name: "A")])
        let sut = makeSUT(fetch: fetch)
        await sut.load()

        await sut.refresh()

        #expect(sut.cards.value?.map(\.id) == ["1"])
        #expect(sut.cards.isLoading == false)
    }

    // MARK: - Search

    @Test("검색어는 앞뒤 공백을 떼고 넘어간다")
    func queryIsTrimmed() async {
        let fetch = StubFetchReceivedCards(result: [])
        let sut = makeSUT(fetch: fetch)
        sut.searchText = "  제옹  "

        await sut.load()

        #expect(fetch.lastQuery == "제옹")
    }

    /// 공백만 남은 검색어를 그대로 넘기면 아무것도 안 걸려 목록이 빈 화면이 된다.
    /// 사용자 눈에는 「전부 사라짐」으로 보이므로 전체 조회로 되돌린다.
    @Test("공백뿐인 검색어는 질의로 넘기지 않는다")
    func blankQueryBecomesNil() async {
        let fetch = StubFetchReceivedCards(result: [])
        let sut = makeSUT(fetch: fetch)
        sut.searchText = "   "

        await sut.load()

        #expect(fetch.lastQuery == nil)
    }

    // MARK: - Sync

    /// 서버가 죽었다고 이미 손에 있는 명함첩까지 못 보게 되면 안 된다. 캐시가 정본이 아닌
    /// 것과 캐시를 못 보여주는 것은 다른 문제다.
    @Test("동기화가 실패해도 캐시 목록은 loaded 로 남는다")
    func syncFailureKeepsCachedList() async {
        let fetch = StubFetchReceivedCards(result: [makeCard(id: "1", name: "A")])
        let sync = StubSyncReceivedCards()
        sync.error = StubError.boom
        let sut = makeSUT(fetch: fetch, sync: sync)

        await sut.load()

        #expect(sut.cards.value?.count == 1)
        #expect(sut.cards.error == nil)
        #expect(sync.callCount == 1)
    }

    /// 화면 진입은 캐시를 먼저 그리고 서버를 맞춘 뒤 다시 그린다. 한 글자 칠 때마다
    /// 서버를 두드리면 안 되므로 디바운스 경로는 캐시만 다시 읽는다.
    @Test("검색 디바운스는 동기화를 부르지 않는다")
    func debounceDoesNotSync() async throws {
        let sync = StubSyncReceivedCards()
        let sut = makeSUT(fetch: StubFetchReceivedCards(result: []), sync: sync)

        sut.searchText = "제옹"
        try await Task.sleep(for: .milliseconds(600))

        #expect(sync.callCount == 0)
    }

    @Test("검색어를 입력하면 직접 부르지 않아도 디바운스 뒤 다시 조회한다")
    func typingTriggersDebouncedReload() async throws {
        let fetch = StubFetchReceivedCards(result: [])
        let sut = makeSUT(fetch: fetch)

        sut.searchText = "제옹"
        try await Task.sleep(for: .milliseconds(600))

        #expect(fetch.callCount == 1)
        #expect(fetch.lastQuery == "제옹")
    }
}

// MARK: - Fixture

/// 저장소는 아무 에러나 던질 수 있다. 특정 에러 타입에 묶지 않으려고 로컬 타입을 쓴다.
private enum StubError: Error {
    case boom
}

private func makeCard(id: String, name: String) -> ReceivedCard {
    ReceivedCard(
        id: id,
        profile: MyCard(
            memberId: id, name: name, nickname: "\(name)닉",
            part: .design, generation: "11", university: "중앙대학교",
            email: nil, github: nil, linkedIn: nil, blog: nil, avatarURL: nil
        ),
        exchangedAt: Date(timeIntervalSince1970: 0),
        exchangeContext: nil
    )
}

@MainActor
private func makeSUT(
    fetch: StubFetchReceivedCards,
    sync: StubSyncReceivedCards = StubSyncReceivedCards()
) -> ReceivedCardsViewModel {
    ReceivedCardsViewModel(fetchReceivedCards: fetch, syncReceivedCards: sync)
}

// MARK: - Stub

private final class StubFetchReceivedCards:
    FetchReceivedCardsUseCaseProtocol, @unchecked Sendable {

    private let result: [ReceivedCard]
    private let error: Error?
    private(set) var lastQuery: String?
    private(set) var callCount = 0

    init(result: [ReceivedCard] = [], error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func execute(query: String?) async throws -> [ReceivedCard] {
        callCount += 1
        lastQuery = query
        if let error { throw error }
        return result
    }
}

private final class StubSyncReceivedCards:
    SyncReceivedCardsUseCaseProtocol, @unchecked Sendable {

    var error: Error?
    private(set) var callCount = 0

    func execute() async throws {
        callCount += 1
        if let error { throw error }
    }
}
