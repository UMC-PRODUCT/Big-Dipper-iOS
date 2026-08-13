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
/// 대신 메인 액터 hop 이 없어 재진입 경합(늦게 도착한 응답이 덮어쓰기)은 이 대역으로 재현할 수
/// 없다 — 그런 테스트가 필요해지면 `actor` 대역 + continuation 게이트로 가야 한다.
@MainActor
private final class StubListUseCase: CommunityThreadListUseCaseProtocol {

    var page = CommunityThreadPage(pinned: [], threads: [], nextOffset: nil, total: "0")
    var pagesByOffset: [Int: CommunityThreadPage] = [:]
    var shouldFailLoad = false
    var shouldFailToggle = false

    private(set) var requestedOffsets: [Int] = []
    private(set) var requestedQueries: [String?] = []
    private(set) var pinCalls: [(threadId: String, isPinned: Bool)] = []
    private(set) var leaveCalls: [String] = []
    private(set) var deleteCalls: [String] = []

    func loadThreads(
        filter: CommunityThreadFilter,
        query: String?,
        offset: Int
    ) async throws -> CommunityThreadPage {
        requestedOffsets.append(offset)
        requestedQueries.append(query)
        if shouldFailLoad { throw AppError.unknown(message: "실패") }
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
        leaveCalls.append(threadId)
        if shouldFailToggle { throw AppError.unknown(message: "실패") }
    }

    func deleteThread(threadId: String) async throws {
        deleteCalls.append(threadId)
        if shouldFailToggle { throw AppError.unknown(message: "실패") }
    }
}

/// 실시간 결선만 확인하기 위한 최소 대역 — 미리 심어 둔 신호를 흘리고 스트림을 닫는다.
@MainActor
private final class StubRoomUseCase: CommunityThreadRoomUseCaseProtocol {

    var pendingSignals: [CommunityRealtimeSignal] = []

    func loadThread(threadId: String) async throws -> CommunityThread {
        makeThread(id: threadId)
    }

    func loadMessages(threadId: String, before: String?) async throws -> ThreadMessagePage {
        ThreadMessagePage(messages: [], hasMore: false, nextBefore: nil)
    }

    func loadMembers(threadId: String) async throws -> [ThreadMember] { [] }

    func send(
        threadId: String,
        clientMessageId: String,
        content: String,
        replyToId: String?,
        mentionedMemberIds: [String]
    ) async throws {}

    func markRead(threadId: String, lastReadMessageId: String) async throws {}

    func addReaction(threadId: String, messageId: String, emoji: String) async throws {}

    func removeReaction(threadId: String, messageId: String, emoji: String) async throws {}

    func deleteMessage(threadId: String, messageId: String) async throws {}

    func reportMessage(messageId: String, reason: ThreadMessageReportReason) async throws {}

    func startRealtime() async {}

    func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        let signals = pendingSignals
        return AsyncStream { continuation in
            signals.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

private func makeThread(
    id: String,
    isPinned: Bool = false,
    unreadCount: String = "0",
    memberCount: String = "3"
) -> CommunityThread {
    CommunityThread(
        id: id,
        title: "스레드 \(id)",
        description: "",
        category: .free,
        icon: "",
        memberCount: memberCount,
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

private func makeMessage(
    threadId: String,
    content: String,
    senderId: String = "9"
) -> ThreadMessage {
    ThreadMessage(
        id: "10",
        threadId: threadId,
        senderId: senderId,
        senderName: "정의진",
        content: content,
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
}

// MARK: - Tests

@Suite("CommunityThreadListViewModel")
@MainActor
struct CommunityThreadListViewModelTests {

    /// `currentMemberId` 는 항상 주입한다 — 기본값은 실제 `UserDefaults` 를 읽어 테스트가
    /// 로컬 로그인 상태에 끌려간다. 이 스위트에서 나는 `"1"`, 남은 `"9"` 다.
    private func makeViewModel(
        _ useCase: StubListUseCase,
        roomUseCase: StubRoomUseCase? = nil,
        errorHandler: ErrorHandler = ErrorHandler(),
        currentMemberId: String? = "1"
    ) -> CommunityThreadListViewModel {
        CommunityThreadListViewModel(
            listUseCase: useCase,
            roomUseCase: roomUseCase,
            errorHandler: errorHandler,
            currentMemberId: currentMemberId
        )
    }

    /// 언스트럭처드 `Task`(AlertPrompt 액션·강퇴 재조회)와 검색 디바운스를 기다린다.
    /// 상한은 `.timeLimit` 트레이트가 잡으므로 여기서 횟수를 세지 않는다.
    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Load

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

    @Test("첫 로드 실패는 화면 내 인라인 상태로 남는다 — 전역 Alert 이 아니다")
    func failedLoadStaysInline() async {
        let useCase = StubListUseCase()
        useCase.shouldFailLoad = true
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)

        await viewModel.load()

        #expect(viewModel.state.error != nil)
        #expect(errorHandler.currentError == nil)
    }

    @Test("새로고침 실패는 목록을 지우지 않고 전역 Alert 으로 알린다")
    func failedRefreshKeepsList() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)
        await viewModel.load()

        useCase.shouldFailLoad = true
        await viewModel.refresh()

        #expect(viewModel.state.value?.map(\.id) == ["1"])
        #expect(errorHandler.currentError != nil)
    }

    @Test("검색어는 공백을 털어 보내고, 공백뿐이면 검색하지 않는다", .timeLimit(.minutes(1)))
    func normalizesSearchQuery() async {
        let useCase = StubListUseCase()
        let viewModel = makeViewModel(useCase)

        viewModel.searchText = "  iOS 스터디  "
        await waitUntil { useCase.requestedQueries.count == 1 }

        viewModel.searchText = "   "
        await waitUntil { useCase.requestedQueries.count == 2 }

        #expect(useCase.requestedQueries == ["iOS 스터디", nil])
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

    @Test("이미 가진 스레드가 다음 페이지에 다시 오면 중복으로 쌓지 않는다")
    func skipsDuplicatesAcrossPages() async {
        let useCase = StubListUseCase()
        useCase.pagesByOffset = [
            0: CommunityThreadPage(
                pinned: [], threads: [makeThread(id: "1")], nextOffset: "20", total: "2"
            ),
            20: CommunityThreadPage(
                pinned: [],
                threads: [makeThread(id: "1"), makeThread(id: "2")],
                nextOffset: nil,
                total: "2"
            )
        ]
        let viewModel = makeViewModel(useCase)

        await viewModel.load()
        await viewModel.loadNextPageIfNeeded(currentItem: makeThread(id: "1"))

        #expect(viewModel.state.value?.map(\.id) == ["1", "2"])
    }

    // MARK: - Create

    @Test("생성한 스레드는 목록 맨 위에 붙고, 재조회가 먼저 넣었으면 중복되지 않는다")
    func insertsCreatedThreadOnce() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [],
            threads: [makeThread(id: "1")],
            nextOffset: nil,
            total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.insertCreated(makeThread(id: "9"))
        #expect(viewModel.state.value?.map(\.id) == ["9", "1"])

        viewModel.insertCreated(makeThread(id: "9"))
        #expect(viewModel.state.value?.map(\.id) == ["9", "1"])
    }

    // MARK: - Toggle & Leave

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

        #expect(useCase.pinCalls.map(\.threadId) == ["1"])
        #expect(useCase.pinCalls.map(\.isPinned) == [true])
        // 낙관적으로 올렸다가 실패해 원위치.
        #expect(viewModel.pinned.isEmpty)
        #expect(viewModel.state.value?.map(\.id) == ["1"])
    }

    /// 완료 조건 3 — 방에서 고정·알림을 바꾸고 돌아오면 목록이 그 상태여야 한다 (#1138).
    @Test("채팅방에서 바꾼 고정·알림을 행에 반영한다")
    func appliesTogglesFromRoom() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1"), makeThread(id: "2")],
            nextOffset: nil, total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.applyToggles(makeThread(id: "1", isPinned: true).with(isMuted: true))

        // 고정은 섹션 이동까지 따라야 한다 — 값만 바꾸면 일반 목록에 고정 배지가 남는다.
        #expect(viewModel.pinned.map(\.id) == ["1"])
        #expect(viewModel.state.value?.map(\.id) == ["2"])
        #expect(viewModel.pinned.first?.isMuted == true)
    }

    @Test("이미 같은 상태인 행은 고정 해제만 반영한다")
    func appliesUnpinFromRoom() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [makeThread(id: "1", isPinned: true)], threads: [makeThread(id: "2")],
            nextOffset: nil, total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.applyToggles(makeThread(id: "1"))

        #expect(viewModel.pinned.isEmpty)
        #expect(viewModel.state.value?.map(\.id) == ["1", "2"])
    }

    @Test("나가기는 확인을 받은 뒤에만 실행된다", .timeLimit(.minutes(1)))
    func leavesOnlyAfterConfirmation() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.confirmLeave(makeThread(id: "1"))

        #expect(useCase.leaveCalls.isEmpty)
        #expect(viewModel.state.value?.map(\.id) == ["1"])

        let confirm = try #require(viewModel.alertPrompt?.positiveBtnAction)
        confirm()
        await waitUntil { useCase.leaveCalls.isEmpty == false }

        #expect(viewModel.state.value?.isEmpty == true)
    }

    // MARK: - Realtime

    @Test("메시지 이벤트는 해당 행의 미리보기와 안읽음을 갱신한다")
    func appliesMessageEvent() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        let message = makeMessage(threadId: "1", content: "새 메시지")
        viewModel.apply(.messageCreated(threadId: "1", message: message, clientMessageId: nil))

        let row = try #require(viewModel.state.value?.first)
        #expect(row.lastMessage?.preview == "새 메시지")
        #expect(row.unreadCount == "1")
    }

    @Test("내가 보낸 메시지는 미리보기만 바꾸고 안읽음 배지는 올리지 않는다")
    func skipsUnreadForOwnMessage() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 내가 보낸 메시지도 유저 단위 팬아웃으로 되돌아온다.
        let mine = makeMessage(threadId: "1", content: "내 메시지", senderId: "1")
        viewModel.apply(.messageCreated(threadId: "1", message: mine, clientMessageId: nil))

        let row = try #require(viewModel.state.value?.first)
        #expect(row.lastMessage?.preview == "내 메시지")
        #expect(row.unreadCount == "0")
    }

    @Test("채팅방에 들어가면 그 행의 안읽음 배지를 로컬로 0 으로 내린다")
    func clearsUnreadOnThreadOpen() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [],
            threads: [
                makeThread(id: "1", unreadCount: "5"),
                makeThread(id: "2", unreadCount: "3")
            ],
            nextOffset: nil,
            total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.markThreadRead(threadId: "1")

        let rows = try #require(viewModel.state.value)
        #expect(rows.map(\.unreadCount) == ["0", "3"])
    }

    @Test("목록에 없는 스레드의 이벤트는 아무것도 바꾸지 않는다")
    func ignoresEventForUnknownThread() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [makeThread(id: "1", isPinned: true)],
            threads: [makeThread(id: "2")],
            nextOffset: nil,
            total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()
        let before = viewModel.state

        let message = makeMessage(threadId: "999", content: "남의 스레드")
        viewModel.apply(.messageCreated(threadId: "999", message: message, clientMessageId: nil))
        viewModel.apply(.threadDeleted(threadId: "999", deletedAt: Date()))

        #expect(viewModel.state == before)
        #expect(viewModel.pinned.map(\.id) == ["1"])
    }

    @Test("남의 읽음 영수증은 내 안읽음 배지를 건드리지 않는다")
    func ignoresOthersReadReceipt() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [],
            threads: [makeThread(id: "1", unreadCount: "5")],
            nextOffset: nil,
            total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 유저 단위 팬아웃이라 같은 스레드 팀원의 영수증도 내 큐로 온다.
        viewModel.apply(.readUpdated(threadId: "1", memberId: "9", lastReadMessageId: "10"))

        let row = try #require(viewModel.state.value?.first)
        #expect(row.unreadCount == "5")
    }

    @Test("강퇴 이벤트는 행을 지우지 않고 REST 로 최종 상태를 확인한다", .timeLimit(.minutes(1)))
    func refetchesInsteadOfRemovingOnKick() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 남이 강퇴당한 이벤트도 그대로 도착한다. 지워 버리면 모두의 목록에서 사라진다.
        viewModel.apply(.memberKicked(threadId: "1", memberId: "9", memberCount: "2"))

        #expect(viewModel.state.value?.map(\.id) == ["1"])
        #expect(viewModel.state.value?.first?.memberCount == "2")

        await waitUntil { useCase.requestedOffsets.count == 2 }
        #expect(useCase.requestedOffsets == [0, 0])
    }

    @Test("목록에 없는 스레드의 강퇴 이벤트는 재조회를 부르지 않는다", .timeLimit(.minutes(1)))
    func skipsRefetchForUnknownThreadKick() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.memberKicked(threadId: "999", memberId: "9", memberCount: "2"))

        // 부정 단언이라 기다릴 조건이 없다. 언스트럭처드 재조회 Task 가 돌 틈만 준다.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(useCase.requestedOffsets == [0])
    }

    @Test("내가 다른 기기에서 나간 이벤트는 행을 지운다")
    func removesRowWhenILeaveFromAnotherDevice() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [makeThread(id: "1", isPinned: true)],
            threads: [makeThread(id: "2")],
            nextOffset: nil,
            total: "2"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.memberLeft(threadId: "1", memberId: "1", memberCount: "2"))
        viewModel.apply(.memberLeft(threadId: "2", memberId: "1", memberCount: "2"))

        #expect(viewModel.pinned.isEmpty)
        #expect(viewModel.state.value?.isEmpty == true)
    }

    @Test("남이 나간 이벤트는 멤버 수만 줄이고 행은 남긴다")
    func keepsRowWhenSomeoneElseLeaves() async throws {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [],
            threads: [makeThread(id: "1", memberCount: "3")],
            nextOffset: nil,
            total: "1"
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.memberLeft(threadId: "1", memberId: "9", memberCount: "2"))

        let row = try #require(viewModel.state.value?.first)
        #expect(row.id == "1")
        #expect(row.memberCount == "2")
    }

    @Test("재연결 재조회는 실패해도 전역 Alert 을 띄우지 않는다", .timeLimit(.minutes(1)))
    func staysSilentWhenReconnectRefreshFails() async {
        let useCase = StubListUseCase()
        useCase.page = CommunityThreadPage(
            pinned: [], threads: [makeThread(id: "1")], nextOffset: nil, total: "1"
        )
        let roomUseCase = StubRoomUseCase()
        roomUseCase.pendingSignals = [.reconnected]
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(
            useCase,
            roomUseCase: roomUseCase,
            errorHandler: errorHandler
        )
        await viewModel.load()

        useCase.shouldFailLoad = true
        await viewModel.observeRealtime()

        // 재조회는 실제로 돈다 — 조용할 뿐이다. 사용자가 당긴 새로고침 실패는
        // `failedRefreshKeepsList` 가 Alert 을 요구한다.
        #expect(useCase.requestedOffsets == [0, 0])
        #expect(errorHandler.currentError == nil)
        #expect(viewModel.state.value?.map(\.id) == ["1"])
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
