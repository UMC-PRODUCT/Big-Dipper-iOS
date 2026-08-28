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
@Suite("ReceivedCardsViewModel — 명함첩 로드·검색·삭제")
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

    @Test("검색어를 입력하면 직접 부르지 않아도 디바운스 뒤 다시 조회한다")
    func typingTriggersDebouncedReload() async throws {
        let fetch = StubFetchReceivedCards(result: [])
        let sut = makeSUT(fetch: fetch)

        sut.searchText = "제옹"
        try await Task.sleep(for: .milliseconds(600))

        #expect(fetch.callCount == 1)
        #expect(fetch.lastQuery == "제옹")
    }

    // MARK: - Delete

    @Test("삭제하면 목록에서 빠진다")
    func deleteRemovesFromList() async {
        let delete = StubDeleteReceivedCard()
        let sut = makeSUT(
            fetch: StubFetchReceivedCards(result: [
                makeCard(id: "1", name: "A"), makeCard(id: "2", name: "B"),
            ]),
            delete: delete
        )
        await sut.load()

        await sut.delete(id: "1")

        #expect(delete.deletedIDs == ["1"])
        #expect(sut.cards.value?.map(\.id) == ["2"])
    }

    /// 명함첩은 서버 사본이 없다 — 지우면 그 명함은 다시 교환하기 전까지 복구할 수 없다.
    /// 그래서 그리드에서 바로 지우지 않고 확인을 한 번 받는다.
    @Test("삭제를 요청하면 곧바로 지우지 않고 확인 다이얼로그를 띄운다")
    func requestDeleteAsksFirst() async {
        let delete = StubDeleteReceivedCard()
        let sut = makeSUT(
            fetch: StubFetchReceivedCards(result: [makeCard(id: "1", name: "A")]),
            delete: delete
        )
        await sut.load()

        sut.requestDelete(makeCard(id: "1", name: "A"))

        #expect(sut.alertPrompt?.isPositiveBtnDestructive == true)
        #expect(delete.deletedIDs.isEmpty)
        #expect(sut.cards.value?.count == 1)
    }

    /// 실패했는데 행을 지워 버리면 사용자는 지워진 줄 알고 화면을 뜨고, 다음 진입에서
    /// 되살아난 명함을 본다. 실패는 목록을 건드리지 않고 알리기만 한다.
    @Test("삭제가 실패하면 목록을 그대로 두고 에러를 알린다")
    func deleteFailureKeepsList() async {
        let errorHandler = ErrorHandler()
        let sut = makeSUT(
            fetch: StubFetchReceivedCards(result: [makeCard(id: "1", name: "A")]),
            delete: StubDeleteReceivedCard(error: StubError.boom),
            errorHandler: errorHandler
        )
        await sut.load()

        await sut.delete(id: "1")

        #expect(sut.cards.value?.map(\.id) == ["1"])
        #expect(errorHandler.currentError != nil)
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
    delete: StubDeleteReceivedCard = StubDeleteReceivedCard(),
    errorHandler: ErrorHandler = ErrorHandler()
) -> ReceivedCardsViewModel {
    ReceivedCardsViewModel(
        fetchReceivedCards: fetch,
        deleteReceivedCard: delete,
        errorHandler: errorHandler
    )
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

private final class StubDeleteReceivedCard:
    DeleteReceivedCardUseCaseProtocol, @unchecked Sendable {

    private let error: Error?
    private(set) var deletedIDs: [String] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func execute(id: String) async throws {
        deletedIDs.append(id)
        if let error { throw error }
    }

    func executeAll() async throws {
        if let error { throw error }
    }
}
