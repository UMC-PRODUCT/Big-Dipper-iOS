//
//  CommunityThreadListViewModelTests.swift
//  CommunityPresentationTests
//

import Foundation
import Testing
import CommunityDomain
import UMCFoundation
@testable import CommunityPresentation

// MARK: - Test Double

/// 호출을 기록하고 결과를 미리 심어 두는 UseCase 대역.
///
/// 스위트가 `@MainActor` 라 대역도 같은 격리에 두면 `await` 없이 기록을 검증할 수 있다.
@MainActor
private final class StubListUseCase: CommunityThreadListUseCaseProtocol {

    var page = CommunityThreadPage(pinned: [], threads: [], nextOffset: nil, total: "0")
    var pagesByOffset: [Int: CommunityThreadPage] = [:]
    var shouldFailToggle = false

    private(set) var requestedOffsets: [Int] = []
    private(set) var requestedQueries: [String?] = []
    private(set) var pinCalls: [(String, Bool)] = []

    func loadThreads(
        filter: CommunityThreadFilter,
        query: String?,
        offset: Int
    ) async throws -> CommunityThreadPage {
        requestedOffsets.append(offset)
        requestedQueries.append(query)
        return pagesByOffset[offset] ?? page
    }

    func togglePin(threadId: String, isPinned: Bool) async throws {
        pinCalls.append((threadId, isPinned))
        if shouldFailToggle { throw AppError.unknown(message: "실패") }
    }

    func toggleMute(threadId: String, isMuted: Bool) async throws {
        if shouldFailToggle { throw AppError.unknown(message: "실패") }
    }

    func leave(threadId: String) async throws {
        if shouldFailToggle { throw AppError.unknown(message: "실패") }
    }
}

private func makeThread(
    id: String,
    isPinned: Bool = false,
    unreadCount: String = "0"
) -> CommunityThread {
    CommunityThread(
        id: id,
        title: "스레드 \(id)",
        description: "",
        category: .free,
        icon: "",
        memberCount: "3",
        unreadCount: unreadCount,
        maxMembers: "20",
        isPinned: isPinned,
        isMuted: false,
        isJoined: true,
        myRole: .member,
        lastMessage: nil,
        createdBy: "1",
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        shareURL: nil,
        deletedAt: nil
    )
}

// MARK: - Tests

@Suite("CommunityThreadListViewModel")
@MainActor
struct CommunityThreadListViewModelTests {

    private func makeViewModel(
        _ useCase: StubListUseCase
    ) -> CommunityThreadListViewModel {
        CommunityThreadListViewModel(
            listUseCase: useCase,
            roomUseCase: nil,
            errorHandler: ErrorHandler()
        )
    }

    @Test("첫 로드는 고정과 일반을 나눠 담는다")
    func loadsFirstPage() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [makeThread(id: "1", isPinned: true)],
            threads: [makeThread(id: "2")],
            nextOffset: "20",
            total: "2"
        )
        let viewModel = makeViewModel(useCase)

        await viewModel.load()

        #expect(viewModel.pinned.map(\.id) == ["1"])
        #expect(viewModel.state.value?.map(\.id) == ["2"])
    }

    @Test("다음 페이지는 이어 붙이고, nextOffset 이 없으면 더 부르지 않는다")
    func appendsNextPage() async {
        let useCase = StubListUseCase()
        useCase.pagesByOffset = [
            0: CommunityThreadPage(
                pinned: [], threads: [makeThread(id: "1")], nextOffset: "20", total: "2"
            ),
            20: CommunityThreadPage(
                pinned: [], threads: [makeThread(id: "2")], nextOffset: nil, total: "2"
            )
        ]
        let viewModel = makeViewModel(useCase)

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItem: makeThread(id: "1"))
        await viewModel.loadNextPageIfNeeded(currentItem: makeThread(id: "2"))

        #expect(viewModel.state.value?.map(\.id) == ["1", "2"])
        #expect(useCase.requestedOffsets == [0, 20])
    }

    @Test("고정 토글은 즉시 반영하고, 실패하면 되돌린다")
    func rollsBackFailedPin() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        useCase.shouldFailToggle = true
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        await viewModel.togglePin(makeThread(id: "1"))

        #expect(useCase.pinCalls.map(\.1) == [true])
        // 낙관적으로 올렸다가 실패해 원위치.
        #expect(viewModel.pinned.isEmpty)
        #expect(viewModel.state.value?.map(\.id) == ["1"])
    }

    @Test("메시지 이벤트는 해당 행의 미리보기와 안읽음을 갱신한다")
    func appliesMessageEvent() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        let message = ThreadMessage(
            id: "10",
            threadId: "1",
            senderId: "9",
            senderName: "정의진",
            content: "새 메시지",
            type: .text,
            files: [],
            mentions: [],
            replyTo: nil,
            reactions: [],
            clientMessageId: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            editedAt: nil,
            deletedAt: nil,
            deliveryState: .sent
        )
        viewModel.apply(.messageCreated(threadId: "1", message: message, clientMessageId: nil))

        let row = try? #require(viewModel.state.value?.first)
        #expect(row?.lastMessage?.preview == "새 메시지")
        #expect(row?.unreadCount == "1")
    }

    @Test("종료성 이벤트는 행을 지운다")
    func removesRowOnTerminalEvent() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [makeThread(id: "1", isPinned: true)],
            threads: [makeThread(id: "2")],
            nextOffset: nil,
            total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.threadDeleted(threadId: "1", deletedAt: Date()))

        #expect(viewModel.pinned.isEmpty)
        #expect(viewModel.state.value?.map(\.id) == ["2"])
    }
}
