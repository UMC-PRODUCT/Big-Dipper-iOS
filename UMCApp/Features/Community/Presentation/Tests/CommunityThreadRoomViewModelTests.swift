//
//  CommunityThreadRoomViewModelTests.swift
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
/// 대신 액터 hop 이 없어 "전송 in-flight 중 에코 도착" 같은 경합은 재현할 수 없다 —
/// 그건 아래 `GatedRoomUseCase` 가 맡는다.
@MainActor
private final class StubRoomUseCase: CommunityThreadRoomUseCaseProtocol {

    var thread = makeThread()
    var pages: [String?: ThreadMessagePage] = [:]
    var sendError: Error?
    var loadThreadError: Error?
    var loadMessagesError: Error?
    /// 구독하자마자 흘려보낼 신호. 다 흘리면 스트림이 끝나 `observeRealtime()` 이 반환한다.
    var pendingSignals: [CommunityRealtimeSignal] = []

    private(set) var sentContents: [String] = []
    private(set) var sentClientMessageIds: [String] = []
    private(set) var readWatermarks: [String] = []
    private(set) var loadThreadCount = 0

    func loadThread(threadId: String) async throws -> CommunityThread {
        loadThreadCount += 1
        if let loadThreadError { throw loadThreadError }
        return thread
    }

    func loadMessages(threadId: String, before: String?) async throws -> ThreadMessagePage {
        if let loadMessagesError { throw loadMessagesError }
        return pages[before] ?? ThreadMessagePage(messages: [], hasMore: false, nextBefore: nil)
    }

    func send(threadId: String, clientMessageId: String, content: String) async throws {
        sentClientMessageIds.append(clientMessageId)
        sentContents.append(content)
        if let sendError { throw sendError }
    }

    func markRead(threadId: String, lastReadMessageId: String) async throws {
        readWatermarks.append(lastReadMessageId)
    }

    func startRealtime() async {}

    func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        let signals = pendingSignals
        return AsyncStream { continuation in
            signals.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

/// `send` 를 게이트에 묶어 두는 대역.
///
/// `@MainActor` 대역은 VM 과 같은 격리라 `await` 에서 hop 이 없어 전송 도중 다른 코드가 끼어드는
/// 순서를 만들 수 없다. 경합 계약을 잠그려면 실제로 격리를 넘어야 한다 (Data 레이어 선례와 동일).
private actor GatedRoomUseCase: CommunityThreadRoomUseCaseProtocol {

    private var sendGate: CheckedContinuation<Void, Never>?
    private var arrivalWaiter: CheckedContinuation<Void, Never>?
    private var hasEnteredSend = false
    private var sendError: Error?

    private var loadGate: CheckedContinuation<Void, Never>?
    private var loadWaiter: CheckedContinuation<Void, Never>?
    private var hasEnteredLoad = false
    private var gatesLoad = false

    func loadThread(threadId: String) async throws -> CommunityThread { makeThread() }

    func loadMessages(threadId: String, before: String?) async throws -> ThreadMessagePage {
        guard gatesLoad else {
            return ThreadMessagePage(messages: [], hasMore: false, nextBefore: nil)
        }
        hasEnteredLoad = true
        loadWaiter?.resume()
        loadWaiter = nil

        await withCheckedContinuation { loadGate = $0 }
        return ThreadMessagePage(messages: [], hasMore: false, nextBefore: nil)
    }

    func send(threadId: String, clientMessageId: String, content: String) async throws {
        hasEnteredSend = true
        arrivalWaiter?.resume()
        arrivalWaiter = nil

        await withCheckedContinuation { sendGate = $0 }
        if let sendError { throw sendError }
    }

    func markRead(threadId: String, lastReadMessageId: String) async throws {}

    func startRealtime() async {}

    func signals() async -> AsyncStream<CommunityRealtimeSignal> {
        AsyncStream { $0.finish() }
    }

    /// `send` 가 게이트에 걸릴 때까지 기다린다.
    func waitUntilSending() async {
        guard !hasEnteredSend else { return }
        await withCheckedContinuation { arrivalWaiter = $0 }
    }

    func releaseSend(throwing error: Error?) {
        sendError = error
        sendGate?.resume()
        sendGate = nil
    }

    func enableLoadGate() {
        gatesLoad = true
    }

    /// `loadMessages` 가 게이트에 걸릴 때까지 기다린다.
    func waitUntilLoading() async {
        guard !hasEnteredLoad else { return }
        await withCheckedContinuation { loadWaiter = $0 }
    }

    func releaseLoad() {
        loadGate?.resume()
        loadGate = nil
    }
}

/// 요약기 대역.
///
/// 프로토콜이 `Sendable` 이고 `isAvailable` 이 동기 요구 사항이라 `@MainActor` 로 격리하면
/// 만족시킬 수 없다. 실제로 만지는 쪽은 `@MainActor` 인 스위트와 ViewModel 뿐이라 `@unchecked`
/// 로 잠근다 (같은 이유로 격리를 넘어야 하는 경합 검증은 아래 `GatedSummarizer` 가 맡는다).
private final class StubSummarizer: ThreadSummarizing, @unchecked Sendable {

    var isAvailable: Bool
    var result: Result<ThreadSummary, Error>

    private(set) var receivedMessages: [ThreadMessage] = []
    private(set) var receivedMemberName: String?
    private(set) var callCount = 0

    init(
        isAvailable: Bool = true,
        result: Result<ThreadSummary, Error> = .success(
            ThreadSummary(bullets: ["일정이 정해졌어요"], actionItems: ["회비 납부하기"])
        )
    ) {
        self.isAvailable = isAvailable
        self.result = result
    }

    func summarize(
        messages: [ThreadMessage],
        currentMemberName: String?
    ) async throws -> ThreadSummary {
        callCount += 1
        receivedMessages = messages
        receivedMemberName = currentMemberName
        return try result.get()
    }
}

/// 요약을 게이트에 묶어 두는 대역. 진행 중 상태(`.loading`)를 관찰하려면 실제로 멈춰 세워야 한다.
private actor GatedSummarizer: ThreadSummarizing {

    nonisolated let isAvailable = true

    private var gate: CheckedContinuation<Void, Never>?
    private var arrivalWaiter: CheckedContinuation<Void, Never>?
    private var hasEntered = false

    func summarize(
        messages: [ThreadMessage],
        currentMemberName: String?
    ) async throws -> ThreadSummary {
        hasEntered = true
        arrivalWaiter?.resume()
        arrivalWaiter = nil

        await withCheckedContinuation { gate = $0 }
        return ThreadSummary(bullets: ["요약"], actionItems: [])
    }

    /// `summarize` 가 게이트에 걸릴 때까지 기다린다.
    func waitUntilSummarizing() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { arrivalWaiter = $0 }
    }

    func release() {
        hasEntered = false
        gate?.resume()
        gate = nil
    }
}

private func makeThread(
    isJoined: Bool = true,
    memberCount: String = "3",
    unreadCount: String = "0"
) -> CommunityThread {
    CommunityThread(
        id: "1",
        title: "스레드",
        description: "",
        category: .free,
        icon: "",
        memberCount: memberCount,
        unreadCount: unreadCount,
        maxMembers: "20",
        isPinned: false,
        isMuted: false,
        isJoined: isJoined,
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
    id: String,
    threadId: String = "1",
    content: String = "본문",
    clientMessageId: String? = nil,
    senderId: String = "9",
    createdAt: TimeInterval = 0
) -> ThreadMessage {
    ThreadMessage(
        id: id,
        threadId: threadId,
        senderId: senderId,
        senderName: "정의진",
        content: content,
        type: .text,
        files: [],
        mentions: [],
        replyTo: nil,
        reactions: [],
        clientMessageId: clientMessageId,
        createdAt: Date(timeIntervalSince1970: createdAt),
        editedAt: nil,
        deletedAt: nil,
        deliveryState: .sent
    )
}

// MARK: - Tests

@Suite("CommunityThreadRoomViewModel")
@MainActor
struct CommunityThreadRoomViewModelTests {

    /// `currentMemberId` 는 항상 주입한다 — 기본값은 실제 `UserDefaults` 를 읽어 테스트가
    /// 로컬 로그인 상태에 끌려간다.
    private func makeViewModel(
        _ useCase: StubRoomUseCase,
        errorHandler: ErrorHandler = ErrorHandler(),
        summarizer: ThreadSummarizing = StubSummarizer(),
        currentMemberId: String? = "9",
        sendTimeout: Duration = .seconds(15)
    ) -> CommunityThreadRoomViewModel {
        CommunityThreadRoomViewModel(
            threadId: "1",
            useCase: useCase,
            errorHandler: errorHandler,
            summarizer: summarizer,
            currentMemberId: currentMemberId,
            sendTimeout: sendTimeout
        )
    }

    /// 언스트럭처드 `Task`(타임아웃 감시·워터마크 디바운스·멤버십 재확인)를 기다린다.
    /// 상한은 `.timeLimit` 트레이트가 잡으므로 여기서 횟수를 세지 않는다.
    private func waitUntil(_ condition: () -> Bool) async {
        while !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Load

    @Test("서버가 최신순으로 주므로 화면에는 뒤집어 담는다")
    func reversesHistoryForDisplay() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [
                makeMessage(id: "3", createdAt: 300),
                makeMessage(id: "2", createdAt: 200),
                makeMessage(id: "1", createdAt: 100)
            ],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)

        await viewModel.load()

        #expect(viewModel.messages.map(\.id) == ["1", "2", "3"])
    }

    @Test("첫 로드 실패는 화면 내 인라인 상태로 남는다 — 전역 Alert 이 아니다")
    func failedFirstLoadStaysInline() async {
        let useCase = StubRoomUseCase()
        useCase.loadMessagesError = AppError.unknown(message: "실패")
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)

        await viewModel.load()

        #expect(viewModel.header.error != nil)
        #expect(errorHandler.currentError == nil)
    }

    @Test("이전 페이지는 앞에 붙이고, 이미 가진 메시지는 다시 넣지 않는다")
    func prependsOlderPage() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [makeMessage(id: "3", createdAt: 300)],
            hasMore: true,
            nextBefore: "3"
        )
        useCase.pages["3"] = ThreadMessagePage(
            messages: [makeMessage(id: "3", createdAt: 300), makeMessage(id: "2", createdAt: 200)],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        await viewModel.loadOlderIfNeeded(currentItem: makeMessage(id: "3", createdAt: 300))

        #expect(viewModel.messages.map(\.id) == ["2", "3"])
    }

    @Test("과거를 올려본 뒤 다시 load() 해도 시간순이 뒤집히지 않는다")
    func reloadAfterLoadOlderKeepsChronologicalOrder() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [makeMessage(id: "3", createdAt: 300)],
            hasMore: true,
            nextBefore: "3"
        )
        useCase.pages["3"] = ThreadMessagePage(
            messages: [makeMessage(id: "2", createdAt: 200), makeMessage(id: "1", createdAt: 100)],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()
        await viewModel.loadOlderIfNeeded(currentItem: makeMessage(id: "3", createdAt: 300))
        #expect(viewModel.messages.map(\.id) == ["1", "2", "3"])

        // load() 는 "최신 페이지로 리셋" 이다 — 커서도 되돌아가므로 과거 이력은 다시 올려 받는다.
        await viewModel.load()

        #expect(viewModel.messages.map(\.id) == ["3"])
    }

    @Test("진입하면 가장 최신 메시지로 읽음 워터마크를 보낸다", .timeLimit(.minutes(1)))
    func sendsReadWatermarkOnEntry() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [makeMessage(id: "9", createdAt: 900), makeMessage(id: "8", createdAt: 800)],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)

        await viewModel.load()
        await waitUntil { useCase.readWatermarks.isEmpty == false }

        #expect(useCase.readWatermarks == ["9"])
    }

    // MARK: - Send

    @Test("전송하면 즉시 sending 상태로 꽂히고 draft 가 비워진다")
    func insertsOptimisticMessage() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()

        #expect(viewModel.draft.isEmpty)
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.deliveryState == .sending)
        #expect(useCase.sentContents == ["안녕"])
    }

    @Test("clientMessageId 는 서버 멱등 키라 canonical lowercase UUID 여야 한다")
    func sendsCanonicalLowercaseClientMessageId() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()

        let clientMessageId = try #require(useCase.sentClientMessageIds.first)
        #expect(clientMessageId == clientMessageId.lowercased())
        #expect(UUID(uuidString: clientMessageId) != nil)
    }

    @Test("message.created 가 오면 clientMessageId 로 낙관적 항목을 실제 메시지로 바꾼다")
    func replacesOptimisticMessageOnAck() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()
        let clientMessageId = try #require(useCase.sentClientMessageIds.first)

        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "77", content: "안녕", clientMessageId: clientMessageId),
            clientMessageId: clientMessageId
        ))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == "77")
        #expect(viewModel.messages.first?.deliveryState == .sent)
    }

    @Test("서버가 clientMessageId 를 대문자로 되돌려 줘도 같은 항목을 교체한다")
    func replacesOptimisticMessageOnUppercaseEcho() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()
        let sentId = try #require(useCase.sentClientMessageIds.first)

        let echoed = sentId.uppercased()
        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "77", content: "안녕", clientMessageId: echoed),
            clientMessageId: echoed
        ))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == "77")
        #expect(viewModel.messages.first?.deliveryState == .sent)
    }

    @Test("전송 실패는 버블만 failed 로 바꾸고 전역 Alert 을 띄우지 않는다 (스펙 §7)")
    func failedSendStaysInBubble() async {
        let useCase = StubRoomUseCase()
        useCase.sendError = AppError.unknown(message: "notConnected")
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()

        #expect(viewModel.messages.first?.deliveryState == .failed)
        #expect(errorHandler.currentError == nil)
    }

    @Test("실패한 메시지는 같은 clientMessageId 로 재전송한다")
    func retriesWithSameClientMessageId() async throws {
        let useCase = StubRoomUseCase()
        useCase.sendError = AppError.unknown(message: "실패")
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()

        let failed = try #require(viewModel.messages.first)
        useCase.sendError = nil
        await viewModel.retry(failed)

        #expect(useCase.sentClientMessageIds.count == 2)
        #expect(useCase.sentClientMessageIds[0] == useCase.sentClientMessageIds[1])
        #expect(viewModel.messages.first?.deliveryState == .sending)
    }

    @Test("응답이 아예 오지 않으면 타임아웃으로 failed 가 된다", .timeLimit(.minutes(1)))
    func marksFailedOnTimeout() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase, sendTimeout: .milliseconds(50))
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()
        await waitUntil { viewModel.messages.first?.deliveryState == .failed }

        #expect(viewModel.messages.first?.deliveryState == .failed)
    }

    @Test("에러 프레임이 오면 해당 낙관적 메시지를 failed 로 바꾼다")
    func marksFailedOnCommandError() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()
        let clientMessageId = try #require(useCase.sentClientMessageIds.first)

        viewModel.applyCommandFailure(RealtimeCommandError(
            commandId: "c-1",
            clientMessageId: clientMessageId,
            status: "400",
            code: "INVALID",
            message: "잘못된 요청",
            retryable: false
        ))

        #expect(viewModel.messages.first?.deliveryState == .failed)
    }

    @Test("429 는 안내를 띄우고 전송을 잠근다")
    func locksSendingOnRateLimit() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()
        viewModel.draft = "안녕"

        #expect(viewModel.canSend)

        viewModel.applyCommandFailure(RealtimeCommandError(
            commandId: nil,
            clientMessageId: nil,
            status: "429",
            code: "RATE_LIMITED",
            message: "너무 빠릅니다",
            retryable: true
        ))

        #expect(viewModel.sendCooldownNotice != nil)
        #expect(viewModel.canSend == false)
    }

    @Test("상한을 넘긴 입력은 전송 자체를 하지 않는다 — 실패 왕복을 만들지 않는다")
    func blocksOverlongDraft() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = String(repeating: "가", count: 2_001)
        await viewModel.send()

        #expect(viewModel.canSend == false)
        #expect(useCase.sentContents.isEmpty)
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Realtime

    @Test("이미 있는 메시지는 다시 넣지 않는다 — 재연결 백필과 실시간 수신이 겹친다")
    func ignoresDuplicateMessage() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [makeMessage(id: "5", createdAt: 500)],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "5", createdAt: 500),
            clientMessageId: nil
        ))

        #expect(viewModel.messages.map(\.id) == ["5"])
    }

    @Test("다른 스레드 이벤트는 무시한다 — 구독이 유저별이라 남의 스레드도 흘러 들어온다")
    func ignoresOtherThreadEvent() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        let foreign = makeMessage(id: "99", threadId: "2")
        viewModel.apply(.messageCreated(threadId: "2", message: foreign, clientMessageId: nil))

        #expect(viewModel.messages.isEmpty)
    }

    @Test("삭제 이벤트는 항목을 지우지 않고 톰스톤으로 바꾼다")
    func replacesDeletedMessageWithTombstone() async {
        let useCase = StubRoomUseCase()
        useCase.pages[nil] = ThreadMessagePage(
            messages: [makeMessage(id: "5", createdAt: 500)],
            hasMore: false,
            nextBefore: nil
        )
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        var deleted = makeMessage(id: "5", createdAt: 500)
        deleted.deletedAt = Date(timeIntervalSince1970: 600)
        viewModel.apply(.messageDeleted(threadId: "1", message: deleted))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.isDeleted == true)
    }

    @Test("스레드 삭제는 안내 알림을 띄우고, 확인하면 화면을 닫는다", .timeLimit(.minutes(1)))
    func ejectsOnThreadDelete() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.threadDeleted(threadId: "1", deletedAt: Date()))

        let confirm = try #require(viewModel.alertPrompt?.positiveBtnAction)
        #expect(viewModel.shouldDismiss == false)

        confirm()
        await waitUntil { viewModel.shouldDismiss }

        #expect(viewModel.shouldDismiss)
    }

    @Test("다른 기기에서 내가 나가면 REST 확정 없이 방을 닫는다", .timeLimit(.minutes(1)))
    func ejectsWhenILeaveFromAnotherDevice() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 강퇴와 달리 대상이 명시돼 있다 — 재조회 없이 바로 닫힌다.
        viewModel.apply(.memberLeft(threadId: "1", memberId: "9", memberCount: "2"))

        let confirm = try #require(viewModel.alertPrompt?.positiveBtnAction)
        #expect(useCase.loadThreadCount == 1)

        confirm()
        await waitUntil { viewModel.shouldDismiss }

        #expect(viewModel.shouldDismiss)
    }

    @Test("남이 나가면 멤버 수만 줄고 방에는 그대로 남는다")
    func staysWhenSomeoneElseLeaves() async {
        let useCase = StubRoomUseCase()
        useCase.thread = makeThread(memberCount: "3")
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.apply(.memberLeft(threadId: "1", memberId: "7", memberCount: "2"))

        #expect(viewModel.alertPrompt == nil)
        #expect(viewModel.shouldDismiss == false)
        #expect(viewModel.header.value?.memberCount == "2")
    }

    @Test("남이 강퇴당한 이벤트로 내가 방에서 튕기지 않는다", .timeLimit(.minutes(1)))
    func staysWhenSomeoneElseIsKicked() async {
        let useCase = StubRoomUseCase()
        useCase.thread = makeThread(isJoined: true, memberCount: "2")
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 유저 단위 팬아웃이라 같은 스레드에 남아 있는 나에게도 그대로 도착한다.
        viewModel.apply(.memberKicked(threadId: "1", memberId: "9", memberCount: "2"))
        await waitUntil { useCase.loadThreadCount == 2 }

        #expect(viewModel.alertPrompt == nil)
        #expect(viewModel.shouldDismiss == false)
        #expect(viewModel.header.value?.memberCount == "2")
    }

    @Test("내가 강퇴당했으면 REST 재조회로 확정한 뒤 내보낸다", .timeLimit(.minutes(1)))
    func ejectsWhenRefetchSaysNotJoined() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        useCase.thread = makeThread(isJoined: false, memberCount: "2")
        viewModel.apply(.memberKicked(threadId: "1", memberId: "9", memberCount: "2"))
        await waitUntil { viewModel.alertPrompt != nil }

        #expect(viewModel.alertPrompt != nil)
    }

    @Test("재조회가 전송 단계에서 실패하면 내보내지 않는다 — 네트워크 한 번에 방을 닫으면 안 된다",
          .timeLimit(.minutes(1)))
    func staysWhenMembershipRecheckCannotReachServer() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        useCase.loadThreadError = AppError.network(.timeout)
        viewModel.apply(.memberKicked(threadId: "1", memberId: "9", memberCount: "2"))
        await waitUntil { useCase.loadThreadCount == 2 }

        #expect(viewModel.alertPrompt == nil)
        #expect(viewModel.shouldDismiss == false)
    }

    @Test("재조회가 403 으로 거절되면 확정적 비멤버로 보고 내보낸다", .timeLimit(.minutes(1)))
    func ejectsWhenMembershipRecheckIsForbidden() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        useCase.loadThreadError = AppError.network(.requestFailed(statusCode: 403, data: nil))
        viewModel.apply(.memberKicked(threadId: "1", memberId: "9", memberCount: "2"))
        await waitUntil { viewModel.alertPrompt != nil }

        #expect(viewModel.alertPrompt != nil)
    }

    // MARK: - Reconnect

    @Test("재연결 백필은 멤버십을 먼저 확정하고, 실패해도 전역 Alert 을 띄우지 않는다",
          .timeLimit(.minutes(1)))
    func backfillConfirmsMembershipAndStaysSilent() async {
        let useCase = StubRoomUseCase()
        let errorHandler = ErrorHandler()
        let viewModel = makeViewModel(useCase, errorHandler: errorHandler)
        await viewModel.load()

        useCase.loadMessagesError = AppError.unknown(message: "백필 실패")
        useCase.pendingSignals = [.reconnected]
        await viewModel.observeRealtime()

        #expect(useCase.loadThreadCount == 2)
        #expect(errorHandler.currentError == nil)
    }

    @Test("끊긴 사이에 강퇴당했으면 재연결 시점에 확정해 내보낸다", .timeLimit(.minutes(1)))
    func ejectsWhenKickedWhileDisconnected() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        // 종료성 이벤트는 브로커가 재생하지 않는다 — 재연결 시 REST 로만 알 수 있다.
        useCase.thread = makeThread(isJoined: false, memberCount: "2")
        useCase.pendingSignals = [.reconnected]
        await viewModel.observeRealtime()

        #expect(viewModel.alertPrompt != nil)
    }

    // MARK: - Ownership

    @Test("확정된 메시지의 내 것 판별은 senderId 대조로 한다")
    func identifiesMyMessageBySenderId() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase, currentMemberId: "9")

        #expect(viewModel.isMine(makeMessage(id: "1", senderId: "9")))
        #expect(viewModel.isMine(makeMessage(id: "2", senderId: "7")) == false)
    }

    /// 로그인 응답에서 `memberId` 가 비면 저장값이 nil 이 된다. 그때 내 낙관적 메시지가 수신
    /// 버블로 밀리면 재시도 버튼이 사라져 실패한 전송을 되살릴 방법이 없어진다.
    @Test("memberId 를 몰라도 미확정 메시지는 내 것으로 본다 — 재전송 경로를 지키려고")
    func treatsUnsettledMessageAsMineWithoutMemberId() async {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase, currentMemberId: nil)
        let sending = makeMessage(id: "1", senderId: "").with(deliveryState: .sending)
        let failed = makeMessage(id: "2", senderId: "").with(deliveryState: .failed)

        #expect(viewModel.isMine(sending))
        #expect(viewModel.isMine(failed))
        #expect(viewModel.isMine(makeMessage(id: "3", senderId: "9")) == false)
    }

    @Test("낙관적 메시지도 내 메시지로 판별된다")
    func identifiesOptimisticMessageAsMine() async throws {
        let useCase = StubRoomUseCase()
        let viewModel = makeViewModel(useCase, currentMemberId: "9")
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()

        let optimistic = try #require(viewModel.messages.first)
        #expect(viewModel.isMine(optimistic))
    }

    // MARK: - Race

    @Test("실패로 확정된 뒤에 에코가 오면 서버 확정이 이긴다")
    func lateEchoOverridesFailedMessage() async throws {
        let useCase = StubRoomUseCase()
        useCase.sendError = AppError.unknown(message: "실패")
        let viewModel = makeViewModel(useCase)
        await viewModel.load()

        viewModel.draft = "안녕"
        await viewModel.send()
        let clientMessageId = try #require(useCase.sentClientMessageIds.first)
        #expect(viewModel.messages.first?.deliveryState == .failed)

        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "77", content: "안녕", clientMessageId: clientMessageId),
            clientMessageId: clientMessageId
        ))

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.deliveryState == .sent)
    }

    @Test("load() 응답을 기다리는 동안 도착한 실시간 메시지를 지우지 않는다",
          .timeLimit(.minutes(1)))
    func loadKeepsMessagesArrivedDuringRequest() async {
        let useCase = GatedRoomUseCase()
        await useCase.enableLoadGate()
        let viewModel = CommunityThreadRoomViewModel(
            threadId: "1",
            useCase: useCase,
            errorHandler: ErrorHandler(),
            summarizer: StubSummarizer(),
            currentMemberId: "9",
            sendTimeout: .seconds(15)
        )

        let loading = Task { await viewModel.load() }
        await useCase.waitUntilLoading()
        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "77", createdAt: 700),
            clientMessageId: nil
        ))
        await useCase.releaseLoad()
        await loading.value

        #expect(viewModel.messages.map(\.id) == ["77"])
    }

    @Test("전송이 끝나기 전에 에코가 오면, 뒤늦은 전송 실패가 sent 를 되돌리지 않는다",
          .timeLimit(.minutes(1)))
    func lateSendFailureDoesNotDowngradeAckedMessage() async throws {
        let useCase = GatedRoomUseCase()
        let viewModel = CommunityThreadRoomViewModel(
            threadId: "1",
            useCase: useCase,
            errorHandler: ErrorHandler(),
            summarizer: StubSummarizer(),
            currentMemberId: "9",
            sendTimeout: .seconds(15)
        )
        await viewModel.load()

        viewModel.draft = "안녕"
        let sending = Task { await viewModel.send() }

        await useCase.waitUntilSending()
        let clientMessageId = try #require(viewModel.messages.first?.clientMessageId)

        viewModel.apply(.messageCreated(
            threadId: "1",
            message: makeMessage(id: "77", content: "안녕", clientMessageId: clientMessageId),
            clientMessageId: clientMessageId
        ))
        await useCase.releaseSend(throwing: AppError.unknown(message: "늦은 실패"))
        await sending.value

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.id == "77")
        #expect(viewModel.messages.first?.deliveryState == .sent)
    }

    // MARK: - Summary

    /// 미읽음 N개짜리 방을 연 상태를 만든다. 히스토리는 진입 전에 쌓여 있던 것으로 본다.
    private func makeRoom(
        unreadCount: String,
        historyCount: Int = 30,
        summarizer: ThreadSummarizing
    ) -> (StubRoomUseCase, CommunityThreadRoomViewModel) {
        let useCase = StubRoomUseCase()
        useCase.thread = makeThread(unreadCount: unreadCount)
        useCase.pages[nil] = ThreadMessagePage(
            // 서버는 최신순으로 준다.
            messages: (1...historyCount).reversed().map {
                makeMessage(id: "\($0)", content: "메시지 \($0)", createdAt: TimeInterval($0))
            },
            hasMore: false,
            nextBefore: nil
        )
        return (useCase, makeViewModel(useCase, summarizer: summarizer))
    }

    @Test("미읽음이 임계치에 못 미치면 요약 배너를 띄우지 않는다")
    func hidesSummaryBannerBelowThreshold() async {
        let (_, viewModel) = makeRoom(unreadCount: "9", summarizer: StubSummarizer())

        await viewModel.load()

        #expect(viewModel.isSummaryBannerVisible == false)
    }

    @Test("미읽음이 임계치를 넘으면 요약 배너를 띄운다")
    func showsSummaryBannerAtThreshold() async {
        let (_, viewModel) = makeRoom(unreadCount: "10", summarizer: StubSummarizer())

        await viewModel.load()

        #expect(viewModel.isSummaryBannerVisible)
        #expect(viewModel.entryUnreadCount == 10)
    }

    /// 미지원 기기에 진입점을 노출하면 눌러도 실패만 보게 된다. 아예 감추는 게 맞다.
    @Test("온디바이스 모델을 못 쓰는 기기에서는 임계치를 넘겨도 배너가 없다")
    func hidesSummaryBannerWhenModelUnavailable() async {
        let (_, viewModel) = makeRoom(
            unreadCount: "50",
            summarizer: StubSummarizer(isAvailable: false)
        )

        await viewModel.load()

        #expect(viewModel.isSummaryBannerVisible == false)
    }

    @Test("배너를 닫으면 이 방에 머무는 동안 다시 뜨지 않는다")
    func keepsSummaryBannerDismissed() async {
        let (_, viewModel) = makeRoom(unreadCount: "30", summarizer: StubSummarizer())
        await viewModel.load()

        viewModel.dismissSummaryBanner()

        #expect(viewModel.isSummaryBannerVisible == false)
    }

    /// `load()` 는 성공 직후 읽음 워터마크를 올린다. 배너 조건을 헤더에서 매번 다시 읽으면
    /// 그 뒤 재조회 한 번에 미읽음이 0 으로 정정돼 배너가 사라진다.
    @Test("진입 시점 미읽음 수는 이후 스레드 재조회에도 흔들리지 않는다", .timeLimit(.minutes(1)))
    func keepsEntryUnreadCountAfterRefetch() async {
        let (useCase, viewModel) = makeRoom(unreadCount: "24", summarizer: StubSummarizer())
        await viewModel.load()

        // 강퇴 확인 경로가 스레드를 다시 읽어 헤더를 갈아 끼운다 — 그때 미읽음은 이미 0 이다.
        useCase.thread = makeThread(unreadCount: "0")
        viewModel.apply(.memberKicked(threadId: "1", memberId: "7", memberCount: "2"))
        await waitUntil { useCase.loadThreadCount == 2 }

        #expect(viewModel.entryUnreadCount == 24)
        #expect(viewModel.isSummaryBannerVisible)
    }

    @Test("요약에 넘기는 대화는 미읽음 구간으로 잘린다")
    func summarizesOnlyUnreadWindow() async {
        let summarizer = StubSummarizer()
        let (_, viewModel) = makeRoom(
            unreadCount: "12",
            historyCount: 30,
            summarizer: summarizer
        )
        await viewModel.load()

        await viewModel.requestSummary()

        #expect(summarizer.receivedMessages.count == 12)
        #expect(summarizer.receivedMessages.first?.id == "19")
        #expect(summarizer.receivedMessages.last?.id == "30")
    }

    @Test("액션 아이템 주인 힌트로 내가 보낸 메시지의 발신자 이름을 넘긴다")
    func passesCurrentMemberNameHint() async {
        let summarizer = StubSummarizer()
        let (_, viewModel) = makeRoom(unreadCount: "12", summarizer: summarizer)
        await viewModel.load()

        await viewModel.requestSummary()

        // 히스토리의 `senderId` 는 내 memberId 와 같게 만들어져 있다.
        #expect(summarizer.receivedMemberName == "정의진")
    }

    @Test("요약에 성공하면 결과를 담은 loaded 가 된다")
    func loadsSummaryOnSuccess() async throws {
        let summary = ThreadSummary(bullets: ["회비 일정 공지"], actionItems: ["금요일까지 납부"])
        let summarizer = StubSummarizer(result: .success(summary))
        let (_, viewModel) = makeRoom(unreadCount: "12", summarizer: summarizer)
        await viewModel.load()

        await viewModel.requestSummary()

        #expect(viewModel.summary.value == summary)
    }

    /// 요약 실패는 채팅 흐름을 막지 않는다 — 시트 안 인라인이어야 하고 전역 Alert 이면 안 된다.
    @Test("요약에 실패하면 failed 로 남고 전역 Alert 을 띄우지 않는다")
    func failedSummaryStaysInline() async {
        let errorHandler = ErrorHandler()
        let useCase = StubRoomUseCase()
        useCase.thread = makeThread(unreadCount: "12")
        let summarizer = StubSummarizer(result: .failure(ThreadSummaryError.unavailable))
        let viewModel = makeViewModel(
            useCase,
            errorHandler: errorHandler,
            summarizer: summarizer
        )
        await viewModel.load()

        await viewModel.requestSummary()

        #expect(viewModel.summary.error != nil)
        #expect(errorHandler.currentError == nil)
    }

    @Test("시트를 닫으면 결과를 버려 다음 진입에서 다시 요약한다")
    func resetsSummaryOnDismiss() async {
        let (_, viewModel) = makeRoom(unreadCount: "12", summarizer: StubSummarizer())
        await viewModel.load()
        await viewModel.requestSummary()

        viewModel.dismissSummary()

        #expect(viewModel.summary.isIdle)
    }

    @Test("재시도하면 다시 loading 으로 들어갔다가 결과로 끝난다", .timeLimit(.minutes(1)))
    func retryReentersLoading() async {
        let summarizer = GatedSummarizer()
        let (_, viewModel) = makeRoom(unreadCount: "12", summarizer: summarizer)
        await viewModel.load()

        let first = Task { await viewModel.requestSummary() }
        await summarizer.waitUntilSummarizing()
        #expect(viewModel.summary.isLoading)
        await summarizer.release()
        await first.value
        #expect(viewModel.summary.value != nil)

        let retry = Task { await viewModel.retrySummary() }
        await summarizer.waitUntilSummarizing()
        #expect(viewModel.summary.isLoading)
        await summarizer.release()
        await retry.value

        #expect(viewModel.summary.value != nil)
    }

    /// 시트가 뜨는 동안 `.task` 와 재시도 버튼이 겹쳐 들어오면 같은 요약을 두 번 돌린다.
    @Test("요약이 진행 중이면 재요청을 무시한다", .timeLimit(.minutes(1)))
    func ignoresSummaryRequestWhileLoading() async {
        let summarizer = GatedSummarizer()
        let (_, viewModel) = makeRoom(unreadCount: "12", summarizer: summarizer)
        await viewModel.load()

        let first = Task { await viewModel.requestSummary() }
        await summarizer.waitUntilSummarizing()
        await viewModel.requestSummary()
        #expect(viewModel.summary.isLoading)

        await summarizer.release()
        await first.value

        #expect(viewModel.summary.value != nil)
    }
}
