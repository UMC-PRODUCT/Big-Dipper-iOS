//
//  SearchChallengerViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import ActivityPresentation

#if DEBUG

// MARK: - Test Double

/// 검색 UseCase 가짜 구현.
///
/// 응답을 큐로 넘겨 페이지 순서를 제어하고, 게이트로 특정 호출을 붙잡아 두어
/// "느린 응답이 나중 검색을 덮어쓰는지" 같은 인터리빙을 결정론적으로 재현합니다.
private final class MockSearchChallengersUseCase:
    SearchChallengersUseCaseProtocol, @unchecked Sendable {

    struct Call: Equatable {
        let keyword: String?
        let cursor: Int?
        let size: Int
    }

    enum Outcome {
        case page(ChallengerSearchPage)
        case failure(Error)
    }

    private var outcomes: [Outcome]
    private(set) var calls: [Call] = []

    /// 설정하면 해당 인덱스(0-based)의 호출이 continuation 을 여기 걸어두고 대기한다.
    var gateIndex: Int?
    private(set) var gate: CheckedContinuation<Void, Never>?

    init(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    var isGateArmed: Bool { gate != nil }

    func releaseGate() {
        gate?.resume()
        gate = nil
    }

    func execute(
        keyword: String?,
        cursor: Int?,
        size: Int
    ) async throws -> ChallengerSearchPage {
        let index = calls.count
        calls.append(Call(keyword: keyword, cursor: cursor, size: size))

        // 결과는 **호출 시점**에 집는다. 게이트 뒤에서 꺼내면 큐 소비 순서가 완료 순서를
        // 따라가서, 붙잡아 둔 호출이 뒤에 온 호출의 결과를 가져가 버린다.
        let outcome = outcomes.isEmpty ? nil : outcomes.removeFirst()

        if gateIndex == index {
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }

        switch outcome {
        case .page(let page):
            return page
        case .failure(let error):
            throw error
        case nil:
            return ChallengerSearchPage(challengers: [], hasNext: false, nextCursor: nil)
        }
    }
}

/// 에러 전파 검증용 테스트 에러.
private enum TestError: Error {
    case network
}

// MARK: - Helpers

/// `memberId`·`gen`·`part` 만 검증 대상이고, 나머지는 init 충족용 고정값입니다.
private func makeChallenger(
    memberId: String,
    gen: String = "9",
    name: String = "홍길동",
    nickname: String = "길동",
    part: UMCPartType = .front(type: .ios)
) -> ChallengerInfo {
    ChallengerInfo(
        memberId: memberId,
        challengerId: "C-\(memberId)",
        gen: gen,
        name: name,
        nickname: nickname,
        schoolName: "한성대학교",
        profileImage: nil,
        part: part
    )
}

private func makePage(
    _ challengers: [ChallengerInfo],
    hasNext: Bool = false,
    nextCursor: Int? = nil
) -> ChallengerSearchPage {
    ChallengerSearchPage(
        challengers: challengers,
        hasNext: hasNext,
        nextCursor: nextCursor
    )
}

@MainActor
private func makeViewModel(
    _ outcomes: [MockSearchChallengersUseCase.Outcome]
) -> (SearchChallengerViewModel, MockSearchChallengersUseCase) {
    let useCase = MockSearchChallengersUseCase(outcomes)
    return (SearchChallengerViewModel(searchChallengersUseCase: useCase), useCase)
}

// MARK: - Suite: 검색 상태 전이

@Suite("SearchChallengerViewModel — 검색 상태 전이 (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelSearchTests {

    @Test("검색 성공 시 결과와 커서 정보를 반영한다")
    func loadsFirstPage() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: true, nextCursor: 7))
        ])

        await sut.performSearch(keyword: "길동")

        #expect(sut.loadState == .loaded(true))
        #expect(sut.allChallengers.map(\.memberId) == ["1"])
        #expect(sut.hasNext)
        #expect(useCase.calls == [.init(keyword: "길동", cursor: nil, size: 50)])
    }

    @Test("검색 실패 시 목록을 비우고 실패 상태로 전이한다")
    func failsSearch() async {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")])),
            .failure(TestError.network)
        ])
        await sut.performSearch(keyword: "길동")

        await sut.performSearch(keyword: "철수")

        #expect(sut.allChallengers.isEmpty)
        #expect(sut.hasNext == false)
        if case .failed = sut.loadState {
            // 기대하는 case
        } else {
            Issue.record("loadState 가 .failed 여야 함 — 실제: \(sut.loadState)")
        }
    }

    @Test("도메인 에러는 사용자 메시지를 가진 AppError 로 승격한다")
    func mapsDomainError() async {
        let (sut, _) = makeViewModel([
            .failure(DomainError.custom(message: "검색할 수 없습니다."))
        ])

        await sut.performSearch(keyword: "길동")

        #expect(sut.loadState == .failed(.domain(.custom(message: "검색할 수 없습니다."))))
    }

    @Test("빈 키워드는 서버에 keyword 를 싣지 않는다 (전체 검색)")
    func omitsEmptyKeyword() async {
        let (sut, useCase) = makeViewModel([.page(makePage([]))])

        await sut.performSearch(keyword: "")

        #expect(useCase.calls.first?.keyword == nil)
    }

    @Test("clearSearch 는 결과를 비우고 idle 로 되돌린다")
    func clearsSearch() async {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: true, nextCursor: 7))
        ])
        await sut.performSearch(keyword: "길동")

        sut.clearSearch()

        #expect(sut.loadState == .idle)
        #expect(sut.allChallengers.isEmpty)
        #expect(sut.hasNext == false)
    }

    @Test("retrySearch 는 직전 키워드로 다시 조회한다")
    func retriesWithCurrentKeyword() async {
        let (sut, useCase) = makeViewModel([
            .failure(TestError.network),
            .page(makePage([makeChallenger(memberId: "1")]))
        ])
        await sut.performSearch(keyword: "길동")

        await sut.retrySearch()

        #expect(useCase.calls.count == 2)
        #expect(useCase.calls.last?.keyword == "길동")
        #expect(sut.loadState == .loaded(true))
    }

    @Test("검색한 적 없으면 retrySearch 는 서버를 호출하지 않고 idle 로 남는다")
    func retryWithoutKeywordResetsOnly() async {
        let (sut, useCase) = makeViewModel([])

        await sut.retrySearch()

        #expect(useCase.calls.isEmpty)
        #expect(sut.loadState == .idle)
    }
}

// MARK: - Suite: 취소 처리

@Suite("SearchChallengerViewModel — 취소 처리 (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelCancellationTests {

    @Test(
        "취소는 실패가 아니므로 직전 상태로 롤백한다",
        arguments: [
            CancellationError() as Error,
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled) as Error
        ]
    )
    func rollsBackOnCancellation(error: Error) async {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")])),
            .failure(error)
        ])
        await sut.performSearch(keyword: "길동")
        let stateBeforeCancellation = sut.loadState

        await sut.performSearch(keyword: "철수")

        // 취소를 .failed 로 전이시키면 정상 상황에 "알 수 없는 오류" 카드가 뜬다.
        #expect(sut.loadState == stateBeforeCancellation)
        #expect(sut.allChallengers.map(\.memberId) == ["1"])
    }

    @Test("디바운스 showLoading 뒤 취소돼도 스피너에 갇히지 않는다")
    func doesNotStickInLoadingAfterDebouncedCancellation() async {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")])),
            .failure(CancellationError())
        ])
        await sut.performSearch(keyword: "길동")

        // 실제 화면은 입력 즉시 showLoading() 을 호출하고 디바운스 후 검색한다.
        // 되돌릴 지점을 .loading 으로 잡으면 여기서 영영 스피너가 남는다.
        sut.showLoading()
        await sut.performSearch(keyword: "철수")

        #expect(sut.loadState == .loaded(true))
    }

    @Test("검색 초기화 뒤 도착한 취소가 지워진 결과를 되살리지 않는다")
    func clearedStateSurvivesLateCancellation() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")])),
            .failure(CancellationError())
        ])
        await sut.performSearch(keyword: "길동")
        useCase.gateIndex = 1

        let cancelled = Task { await sut.performSearch(keyword: "철수") }
        await drainUntil { useCase.isGateArmed }

        sut.clearSearch()
        useCase.releaseGate()
        await cancelled.value

        #expect(sut.loadState == .idle)
        #expect(sut.allChallengers.isEmpty)
    }
}

// MARK: - Suite: 요청 토큰 (latest-wins)

@Suite("SearchChallengerViewModel — 요청 토큰 latest-wins (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelRequestTokenTests {

    @Test("늦게 도착한 이전 키워드 응답이 최신 검색 결과를 덮어쓰지 않는다")
    func staleSearchResponseIsDiscarded() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "stale")])),
            .page(makePage([makeChallenger(memberId: "fresh")]))
        ])
        useCase.gateIndex = 0

        let slowSearch = Task { await sut.performSearch(keyword: "길동") }
        await drainUntil { useCase.isGateArmed }

        await sut.performSearch(keyword: "철수")
        useCase.releaseGate()
        await slowSearch.value

        #expect(sut.allChallengers.map(\.memberId) == ["fresh"])
    }

    @Test("검색이 끝나기 전 clearSearch 하면 도착한 응답을 버린다")
    func clearedSearchDiscardsInFlightResponse() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")]))
        ])
        useCase.gateIndex = 0

        let search = Task { await sut.performSearch(keyword: "길동") }
        await drainUntil { useCase.isGateArmed }

        sut.clearSearch()
        useCase.releaseGate()
        await search.value

        #expect(sut.loadState == .idle)
        #expect(sut.allChallengers.isEmpty)
    }
}

// MARK: - Suite: 페이지네이션

@Suite("SearchChallengerViewModel — 커서 페이지네이션 (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelPaginationTests {

    @Test("다음 페이지를 기존 목록에 이어 붙이고 커서를 갱신한다")
    func appendsNextPage() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: true, nextCursor: 7)),
            .page(makePage([makeChallenger(memberId: "2")], hasNext: false, nextCursor: nil))
        ])
        await sut.performSearch(keyword: "길동")

        await sut.fetchNextPage()

        #expect(sut.allChallengers.map(\.memberId) == ["1", "2"])
        #expect(sut.hasNext == false)
        #expect(useCase.calls.last == .init(keyword: "길동", cursor: 7, size: 50))
    }

    @Test("이미 목록에 있는 행은 중복 추가하지 않는다")
    func deduplicatesBySelectionKey() async {
        let duplicated = makeChallenger(memberId: "1")
        let (sut, _) = makeViewModel([
            .page(makePage([duplicated], hasNext: true, nextCursor: 7)),
            .page(makePage([duplicated, makeChallenger(memberId: "2")]))
        ])
        await sut.performSearch(keyword: "길동")

        await sut.fetchNextPage()

        #expect(sut.allChallengers.map(\.memberId) == ["1", "2"])
    }

    @Test("다음 페이지가 없으면 서버를 호출하지 않는다")
    func skipsWhenNoNextPage() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: false, nextCursor: nil))
        ])
        await sut.performSearch(keyword: "길동")

        await sut.fetchNextPage()

        #expect(useCase.calls.count == 1)
    }

    @Test("페이지 조회 실패는 이미 보고 있는 목록을 지우지 않는다")
    func keepsListWhenNextPageFails() async {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: true, nextCursor: 7)),
            .failure(TestError.network)
        ])
        await sut.performSearch(keyword: "길동")

        await sut.fetchNextPage()

        #expect(sut.allChallengers.map(\.memberId) == ["1"])
        #expect(sut.loadState == .loaded(true))
        #expect(sut.hasNext == false)
    }

    @Test("키워드가 바뀐 뒤 도착한 페이지는 새 검색 결과에 섞이지 않는다")
    func staleNextPageIsDiscarded() async {
        let (sut, useCase) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")], hasNext: true, nextCursor: 7)),
            .page(makePage([makeChallenger(memberId: "stale")])),
            .page(makePage([makeChallenger(memberId: "fresh")]))
        ])
        await sut.performSearch(keyword: "길동")
        useCase.gateIndex = 1

        let slowPage = Task { await sut.fetchNextPage() }
        await drainUntil { useCase.isGateArmed }

        await sut.performSearch(keyword: "철수")
        useCase.releaseGate()
        await slowPage.value

        #expect(sut.allChallengers.map(\.memberId) == ["fresh"])
    }
}

// MARK: - Suite: 선택 상태

@Suite("SearchChallengerViewModel — 선택 상태 (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelSelectionTests {

    /// 같은 인물이 기수/파트별로 두 행에 나오는 검색 결과.
    private func makeSiblingPage() -> ChallengerSearchPage {
        makePage([
            makeChallenger(memberId: "1", gen: "9"),
            makeChallenger(memberId: "1", gen: "10"),
            makeChallenger(memberId: "2", gen: "9")
        ])
    }

    @Test("선택 시 같은 memberId 의 모든 행이 함께 선택된다")
    func selectsSiblingRowsTogether() async throws {
        let (sut, _) = makeViewModel([.page(makeSiblingPage())])
        await sut.performSearch(keyword: "길동")
        let target = try #require(sut.allChallengers.first)

        sut.toggleSelection(target)

        #expect(sut.selectedKeys == ["1|9|IOS", "1|10|IOS"])
    }

    @Test("해제 시에도 같은 memberId 의 모든 행이 함께 풀린다")
    func deselectsSiblingRowsTogether() async throws {
        let (sut, _) = makeViewModel([.page(makeSiblingPage())])
        await sut.performSearch(keyword: "길동")
        let target = try #require(sut.allChallengers.first)
        sut.toggleSelection(target)

        sut.toggleSelection(target)

        #expect(sut.selectedKeys.isEmpty)
        #expect(sut.selectedChallengersMap.isEmpty)
    }

    @Test("검색 결과가 바뀌어도 이전 선택은 유지된다")
    func keepsSelectionAcrossSearches() async throws {
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")])),
            .page(makePage([makeChallenger(memberId: "2")]))
        ])
        await sut.performSearch(keyword: "길동")
        sut.toggleSelection(try #require(sut.allChallengers.first))

        await sut.performSearch(keyword: "철수")

        #expect(sut.selectedKeys == ["1|9|IOS"])
    }

    @Test("진입 시 상위 선택 목록을 선택 상태로 복원한다")
    func restoresIncomingSelection() {
        let (sut, _) = makeViewModel([])

        sut.initializeSelection(with: [makeChallenger(memberId: "1")])

        #expect(sut.selectedKeys == ["1|9|IOS"])
        #expect(sut.selectedChallengersMap["1|9|IOS"]?.memberId == "1")
    }

    @Test("확정 목록은 기존 선택 순서를 앞에 두고 새 선택을 뒤에 붙인다")
    func preservesPreviousSelectionOrder() async throws {
        let previous = [makeChallenger(memberId: "2"), makeChallenger(memberId: "1")]
        let (sut, _) = makeViewModel([
            .page(makePage([
                makeChallenger(memberId: "1"),
                makeChallenger(memberId: "2"),
                makeChallenger(memberId: "3")
            ]))
        ])
        sut.initializeSelection(with: previous)
        await sut.performSearch(keyword: "길동")
        sut.toggleSelection(try #require(sut.allChallengers.last))

        let confirmed = sut.confirmedSelection(previousSelection: previous)

        #expect(confirmed.map(\.memberId) == ["2", "1", "3"])
    }

    @Test("확정 전에 해제한 항목은 결과에서 빠진다")
    func dropsDeselectedFromConfirmedSelection() async throws {
        let previous = [makeChallenger(memberId: "1")]
        let (sut, _) = makeViewModel([
            .page(makePage([makeChallenger(memberId: "1")]))
        ])
        sut.initializeSelection(with: previous)
        await sut.performSearch(keyword: "길동")
        sut.toggleSelection(try #require(sut.allChallengers.first))

        let confirmed = sut.confirmedSelection(previousSelection: previous)

        #expect(confirmed.isEmpty)
    }
}

// MARK: - Suite: CSV 일괄 선택

@Suite("SearchChallengerViewModel — CSV 일괄 선택 (도메인 규칙)")
@MainActor
struct SearchChallengerViewModelCSVTests {

    private func makeLoadedViewModel() async -> SearchChallengerViewModel {
        let (sut, _) = makeViewModel([
            .page(makePage([
                makeChallenger(memberId: "1", gen: "9", name: "홍길동", nickname: "길동"),
                makeChallenger(memberId: "1", gen: "10", name: "홍길동", nickname: "길동"),
                makeChallenger(memberId: "2", gen: "9", name: "박철수", nickname: "철수")
            ]))
        ])
        await sut.performSearch(keyword: "")
        return sut
    }

    @Test("이름이 일치하면 같은 memberId 의 모든 행을 선택한다")
    func selectsMatchedSiblings() async {
        let sut = await makeLoadedViewModel()

        sut.applyCSVContent("이름,닉네임\n홍길동,길동")

        #expect(sut.selectedKeys == ["1|9|IOS", "1|10|IOS"])
    }

    @Test("닉네임만 일치해도 선택한다")
    func matchesByNicknameOnly() async {
        let sut = await makeLoadedViewModel()

        sut.applyCSVContent("이름,닉네임\n없는이름,철수")

        #expect(sut.selectedKeys == ["2|9|IOS"])
    }

    @Test("매칭 실패 인원은 결과 Alert 에 명시한다")
    func reportsUnmatchedNames() async {
        let sut = await makeLoadedViewModel()

        sut.applyCSVContent("이름,닉네임\n홍길동,길동\n없는사람,없음")

        let prompt = sut.alertPrompt
        #expect(prompt?.title == "CSV 가져오기 결과")
        #expect(prompt?.message.contains("총 2명 중 1명 매칭 완료") == true)
        #expect(prompt?.message.contains("없는사람/없음") == true)
    }

    @Test("헤더만 있는 CSV 는 실패 안내를 띄우고 선택을 바꾸지 않는다")
    func rejectsHeaderOnlyCSV() async {
        let sut = await makeLoadedViewModel()

        sut.applyCSVContent("이름,닉네임")

        #expect(sut.alertPrompt?.title == "CSV 가져오기 실패")
        #expect(sut.selectedKeys.isEmpty)
    }
}

#endif
