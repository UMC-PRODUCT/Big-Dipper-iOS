//
//  RecentThreadSearchTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Helper

/// 실제 `UserDefaults.standard` 를 건드리지 않도록 스위트마다 독립 suite 를 쓴다.
private func makeStore(_ name: String) -> RecentThreadSearchStore {
    let suiteName = "RecentThreadSearchTests.\(name)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return RecentThreadSearchStore(defaults: defaults)
}

// MARK: - Store

@Suite("RecentThreadSearchStore")
struct RecentThreadSearchStoreTests {

    @Test("최근 검색어는 최신순으로 앞에 쌓인다")
    func addsNewestFirst() {
        let store = makeStore(#function)

        _ = store.add("스터디")
        let terms = store.add("회의")

        #expect(terms == ["회의", "스터디"])
        #expect(store.load() == ["회의", "스터디"])
    }

    @Test("같은 검색어를 다시 검색하면 중복 없이 맨 앞으로 올라온다")
    func movesExistingTermToFront() {
        let store = makeStore(#function)

        _ = store.add("스터디")
        _ = store.add("회의")
        let terms = store.add("스터디")

        #expect(terms == ["스터디", "회의"])
    }

    @Test("대소문자만 다른 항목은 새 표기로 대체된다")
    func replacesCaseInsensitiveDuplicate() {
        let store = makeStore(#function)

        _ = store.add("UMC")
        let terms = store.add("umc")

        #expect(terms == ["umc"])
    }

    @Test("상한을 넘으면 가장 오래된 검색어부터 버린다")
    func dropsOldestBeyondLimit() {
        let store = makeStore(#function)

        for index in 0..<(RecentThreadSearchStore.maxCount + 3) {
            _ = store.add("검색어 \(index)")
        }

        let terms = store.load()
        #expect(terms.count == RecentThreadSearchStore.maxCount)
        #expect(terms.first == "검색어 \(RecentThreadSearchStore.maxCount + 2)")
        #expect(terms.contains("검색어 0") == false)
    }

    @Test("공백만 있는 검색어는 저장하지 않는다")
    func ignoresBlankTerm() {
        let store = makeStore(#function)

        let terms = store.add("   \n ")

        #expect(terms.isEmpty)
    }

    @Test("앞뒤 공백은 털고, 검색어 상한을 넘으면 조회와 같은 길이로 잘라 저장한다")
    func normalizesTerm() {
        let store = makeStore(#function)
        let long = String(repeating: "가", count: CommunityThreadListUseCase.queryMaxLength + 20)

        _ = store.add("  스터디  ")
        let terms = store.add(long)

        #expect(terms[1] == "스터디")
        #expect(
            terms[0].unicodeScalars.count == CommunityThreadListUseCase.queryMaxLength
        )
    }

    @Test("개별 삭제와 전체 삭제가 저장소에 반영된다")
    func removesAndClears() {
        let store = makeStore(#function)

        _ = store.add("스터디")
        _ = store.add("회의")

        #expect(store.remove("스터디") == ["회의"])
        #expect(store.load() == ["회의"])
        #expect(store.clear().isEmpty)
        #expect(store.load().isEmpty)
    }
}

// MARK: - ViewModel

/// 검색어 결선만 확인하는 최소 대역.
@MainActor
private final class StubSearchListUseCase: CommunityThreadListUseCaseProtocol {

    private(set) var requestedQueries: [String?] = []

    func loadThreads(
        filter: CommunityThreadFilter,
        query: String?,
        offset: Int
    ) async throws -> CommunityThreadPage {
        requestedQueries.append(query)
        return CommunityThreadPage(pinned: [], threads: [], nextOffset: nil, total: "0")
    }

    func togglePin(threadId: String, isPinned: Bool) async throws {}
    func toggleMute(threadId: String, isMuted: Bool) async throws {}
    func leave(threadId: String) async throws {}
}

@Suite("CommunityThreadListViewModel 최근 검색어")
@MainActor
struct CommunityThreadListViewModelSearchTests {

    private func makeViewModel(
        _ useCase: StubSearchListUseCase,
        store: RecentThreadSearchStore
    ) -> CommunityThreadListViewModel {
        CommunityThreadListViewModel(
            listUseCase: useCase,
            roomUseCase: nil,
            errorHandler: ErrorHandler(),
            currentMemberId: "1",
            recentSearchStore: store
        )
    }

    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("저장된 검색어는 생성 시점에 올라온다")
    func loadsPersistedTermsOnInit() {
        let store = makeStore(#function)
        _ = store.add("스터디")

        let viewModel = makeViewModel(StubSearchListUseCase(), store: store)

        #expect(viewModel.recentSearches == ["스터디"])
    }

    @Test("최근 검색어를 고르면 그 검색어로 조회가 돈다")
    func applyingRecentSearchTriggersQuery() async {
        let store = makeStore(#function)
        let useCase = StubSearchListUseCase()
        let viewModel = makeViewModel(useCase, store: store)

        viewModel.applyRecentSearch("스터디")

        #expect(viewModel.searchText == "스터디")
        #expect(viewModel.recentSearches == ["스터디"])
        await waitUntil { useCase.requestedQueries.contains("스터디") }
    }

    @Test("검색어를 지우면 검색 문맥이 풀린다")
    func clearSearchResetsQuery() {
        let store = makeStore(#function)
        let viewModel = makeViewModel(StubSearchListUseCase(), store: store)

        viewModel.applyRecentSearch("스터디")
        viewModel.clearSearch()

        #expect(viewModel.trimmedQuery == nil)
    }

    @Test("검색 중이 아니면 기록하지 않는다")
    func recordIsNoOpWithoutQuery() {
        let store = makeStore(#function)
        let viewModel = makeViewModel(StubSearchListUseCase(), store: store)

        viewModel.recordCurrentSearch()

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test("개별·전체 삭제가 화면 상태에 반영된다")
    func deletesReflectOnState() {
        let store = makeStore(#function)
        let viewModel = makeViewModel(StubSearchListUseCase(), store: store)

        viewModel.applyRecentSearch("스터디")
        viewModel.applyRecentSearch("회의")

        viewModel.removeRecentSearch("스터디")
        #expect(viewModel.recentSearches == ["회의"])

        viewModel.clearRecentSearches()
        #expect(viewModel.recentSearches.isEmpty)
    }
}
