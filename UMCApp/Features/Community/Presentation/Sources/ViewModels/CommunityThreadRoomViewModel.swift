//
//  CommunityThreadRoomViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 채팅방 상태 기계.
///
/// 메시지 생성 REST 가 없어(STOMP 전용) 전송 결과를 응답으로 받을 수 없다. 그래서 보낸 즉시
/// 로컬에 `.sending` 으로 꽂고, `clientMessageId` 가 일치하는 `message.created` 가 오면 실제
/// 메시지로 갈아 끼운다. 아무것도 오지 않는 경우를 대비해 타임아웃으로 `.failed` 를 확정한다.
///
/// 구독은 스레드별 topic 이 아니라 **유저 단위 팬아웃**이다(스펙 3.2). 남의 스레드 이벤트도,
/// 같은 스레드에 남아 있는 다른 멤버의 이벤트도 그대로 내 큐로 들어온다. `threadId` 로 거르는
/// 게 첫 단계이고, 그것으로도 대상을 못 가리는 종료성 이벤트는 REST 최종 상태로 확정한다.
@Observable
@MainActor
public final class CommunityThreadRoomViewModel {

    // MARK: - Property

    /// 화면 전체의 첫 로드 상태.
    ///
    /// 헤더와 히스토리 첫 페이지는 한 몸이라 둘 중 하나만 실패해도 방을 열 수 없다. 스펙 §7 이
    /// "히스토리 로드 실패 = 인라인 + 재시도" 를 요구하므로 두 실패를 이 한 상태로 모은다.
    public private(set) var header: Loadable<CommunityThread> = .idle
    /// 표시 순서(오래된 것 → 최신). 서버는 최신순으로 주므로 담을 때 뒤집는다.
    public private(set) var messages: [ThreadMessage] = []
    public private(set) var isLoadingOlder = false

    public var draft: String = ""
    public var alertPrompt: AlertPrompt?
    /// 스레드 삭제·강퇴로 더 볼 것이 없어진 상태. View 가 이걸 보고 리스트로 pop 한다.
    public private(set) var shouldDismiss = false
    /// 429 쿨다운 안내. `nil` 이 아닌 동안 전송이 잠긴다 (스펙 §7).
    public private(set) var sendCooldownNotice: String?

    private let threadId: String
    private let useCase: CommunityThreadRoomUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let sendTimeout: Duration

    @ObservationIgnored private var hasMore = false
    @ObservationIgnored private var nextBefore: String?
    /// clientMessageId → 타임아웃 감시 태스크. 응답이 오면 취소한다.
    @ObservationIgnored private var pendingTimeouts: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var readWatermarkTask: Task<Void, Never>?
    @ObservationIgnored private var lastSentWatermark: String?
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?
    @ObservationIgnored private var membershipCheckTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameter sendTimeout: 이 시간 안에 `message.created` 도 에러도 오지 않으면 실패로 본다.
    public init(
        threadId: String,
        useCase: CommunityThreadRoomUseCaseProtocol,
        errorHandler: ErrorHandler,
        sendTimeout: Duration = .seconds(15)
    ) {
        self.threadId = threadId
        self.useCase = useCase
        self.errorHandler = errorHandler
        self.sendTimeout = sendTimeout
    }

    // MARK: - Computed Property

    /// 전송 버튼 활성 조건 = `validateText` 통과 + 쿨다운 아님. 상한을 넘긴 입력은 서버까지
    /// 보내지 않고 버튼을 잠가 실패 왕복을 없앤다 (스펙 3.3 클라이언트 선반영).
    public var canSend: Bool {
        sendCooldownNotice == nil && (try? CommunityThreadRoomUseCase.validateText(draft)) != nil
    }

    // MARK: - Function

    /// 헤더와 최신 페이지를 병렬로 읽는다. 둘은 서로를 기다릴 이유가 없다.
    public func load() async {
        header = .loading

        async let threadRequest = useCase.loadThread(threadId: threadId)
        async let pageRequest = useCase.loadMessages(threadId: threadId, before: nil)

        do {
            let (thread, page) = try await (threadRequest, pageRequest)
            messages = page.messages.reversed()
            hasMore = page.hasMore
            nextBefore = page.nextBefore
            header = .loaded(thread)
            // 방에 들어온 행위 자체가 읽음이다. 리스트의 미읽음 배지는 이 워터마크가 서버에
            // 닿은 뒤 다음 REST 조회로 정정된다 (스펙 10장 잠정 정책).
            if let newest = messages.last {
                markRead(upTo: newest.id)
            }
        } catch {
            // 취소는 화면을 떠난 정상 흐름이다. 에러 화면으로 바꾸면 안 된다.
            guard !(error is CancellationError) else { return }
            header = .failed(AppError.from(error))
        }
    }

    /// 맨 위 항목이 보이면 이전 페이지를 앞에 붙인다.
    public func loadOlderIfNeeded(currentItem: ThreadMessage) async {
        guard messages.first?.id == currentItem.id else { return }
        await loadOlder()
    }

    public func send() async {
        // 공백·상한 초과·쿨다운을 여기서 끊는다. 서버까지 보내 실패 버블을 만들 이유가 없다.
        guard canSend else { return }

        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        // 서버 멱등 키이자 `message.created` 매칭 열쇠. 대문자 UUID 는 canonical 이 아니다.
        let clientMessageId = UUID().uuidString.lowercased()
        messages.append(optimisticMessage(clientMessageId: clientMessageId, content: content))

        await dispatch(clientMessageId: clientMessageId, content: content)
    }

    /// 실패한 메시지 재전송. 같은 `clientMessageId` 를 다시 쓰면 서버가 중복을 걸러 준다.
    public func retry(_ message: ThreadMessage) async {
        guard sendCooldownNotice == nil,
              let clientMessageId = message.clientMessageId,
              let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }),
              messages[index].deliveryState == .failed else { return }

        messages[index].deliveryState = .sending
        await dispatch(clientMessageId: clientMessageId, content: messages[index].content)
    }

    /// 읽음 워터마크. 스크롤마다 보내면 낭비라 1초 모아서 한 번만 보낸다.
    ///
    /// 이 디바운스는 `start()` 반환 ≠ 연결 완료라는 계약도 함께 흡수한다 — 진입 직후 바로
    /// 보내면 `notConnected` 로 버려진다.
    public func markRead(upTo messageId: String) {
        guard messageId != lastSentWatermark else { return }

        readWatermarkTask?.cancel()
        readWatermarkTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.readWatermarkDebounce)
            guard !Task.isCancelled else { return }
            await self?.sendWatermark(messageId)
        }
    }

    /// 실시간 신호 구독. 화면이 사라지면 `task` 취소로 함께 끝난다.
    ///
    /// 연결 소유권은 앱 생명주기에 있으므로 여기서 `stop()` 을 부르지 않는다. `signals()` 는
    /// 멀티 컨슈머라 리스트 화면이 이미 구독 중이어도 독립적으로 받는다.
    public func observeRealtime() async {
        await useCase.startRealtime()

        for await signal in await useCase.signals() {
            switch signal {
            case .event(let event):
                apply(event)
            case .commandFailed(let error):
                applyCommandFailure(error)
            case .reconnected:
                // 끊긴 동안 온 메시지는 재생되지 않는다. REST 로 공백을 메운다.
                await backfill()
            }
        }
    }

    /// 실시간 이벤트 반영. 테스트가 직접 호출할 수 있게 열어 둔다.
    func apply(_ event: CommunityThreadRealtimeEvent) {
        // 유저 단위 팬아웃이라 다른 스레드 이벤트가 섞여 온다.
        guard event.threadId == threadId else { return }

        switch event {
        case .messageCreated(_, let message, let clientMessageId):
            insertOrReplace(message, clientMessageId: clientMessageId)

        case .messageUpdated(_, let message), .messageDeleted(_, let message):
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
            messages[index] = message

        case .reactionChanged(_, let messageId, let reactions):
            guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
            messages[index].reactions = reactions

        case .threadUpdated(let update):
            guard var thread = header.value else { return }
            thread.title = update.title
            thread.description = update.description
            thread.category = update.category
            thread.icon = update.icon
            thread.memberCount = update.memberCount
            header = .loaded(thread)

        case .memberLeft(_, _, let memberCount):
            updateMemberCount(memberCount)

        case .memberKicked(_, _, let memberCount):
            // 서버가 이벤트마다 ACTIVE 수신자를 재계산해 유저 단위로 팬아웃한다(스펙 :108).
            // "내 큐로 왔다" 는 "내가 대상" 이 아니다 — 남이 강퇴당해도 그대로 도착한다.
            // 바로 내보내면 운영진의 강퇴 한 번에 방에 있던 전원이 튕긴다. 카운트만 반영하고
            // 내가 나가야 하는지는 REST 로 확정한다 (스펙 :126 종료성 이벤트 규칙).
            // TODO: currentMemberId 주입되면 memberId 비교로 대체 - [26.08.12] 정의진
            updateMemberCount(memberCount)
            membershipCheckTask?.cancel()
            membershipCheckTask = Task { [weak self] in await self?.confirmMembership() }

        case .threadDeleted:
            // 삭제는 수신자 전원에게 같은 의미다 — 팬아웃 모호성이 없다.
            eject(message: "이 스레드가 삭제됐어요.")

        case .commandAcknowledged, .readUpdated, .threadInvited, .unknown:
            // command.acknowledged 는 저장 확정이 아니라 접수 확인이다(§3.2) — 상태를 안 바꾼다.
            // read.updated 는 남의 영수증과 구분할 수 없어 no-op (Task 14 와 같은 정책).
            break
        }
    }

    /// 명령 실패 반영. 테스트가 직접 호출할 수 있게 열어 둔다.
    func applyCommandFailure(_ error: RealtimeCommandError) {
        if error.isRateLimited {
            startSendCooldown()
        }
        guard let clientMessageId = error.clientMessageId else { return }
        markFailed(clientMessageId: clientMessageId)
    }

    // MARK: - Private Function

    private func loadOlder() async {
        guard hasMore, let before = nextBefore, !isLoadingOlder else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let page = try await useCase.loadMessages(threadId: threadId, before: before)
            // 커서가 배타적이라 겹치지 않지만, 재연결 백필과 맞물리면 겹칠 수 있어 걸러 낸다.
            let known = Set(messages.map(\.id))
            messages.insert(
                contentsOf: page.messages.reversed().filter { !known.contains($0.id) },
                at: 0
            )
            hasMore = page.hasMore
            nextBefore = page.nextBefore
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "loadOlderMessages",
                retryAction: { [weak self] in await self?.loadOlder() }
            ))
        }
    }

    /// 재연결 직후 공백 메우기. 최신 페이지를 다시 읽어 모르는 것만 붙인다.
    private func backfill() async {
        do {
            let page = try await useCase.loadMessages(threadId: threadId, before: nil)
            // 끊긴 동안 서버에 저장된 내 낙관적 메시지가 섞여 온다. 단순 append 하면 같은
            // 말풍선이 둘 남으므로 clientMessageId 매칭까지 하는 경로로 넣는다.
            for message in page.messages.reversed() {
                insertOrReplace(message, clientMessageId: message.clientMessageId)
            }
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "backfillMessages",
                retryAction: { [weak self] in await self?.backfill() }
            ))
        }
    }

    /// 강퇴 이벤트가 나를 겨눈 것인지 REST 로 확정한다.
    ///
    /// 실패는 "아직 모른다" 로 취급한다 — 네트워크가 한 번 튄 걸로 방에서 내보내면 안 된다.
    private func confirmMembership() async {
        guard let thread = try? await useCase.loadThread(threadId: threadId) else { return }

        guard thread.isJoined else {
            eject(message: "이 스레드에서 내보내졌어요.")
            return
        }
        header = .loaded(thread)
    }

    /// 429 쿨다운. 서버가 남은 시간을 주지 않으므로 고정 시간 뒤에 스스로 푼다.
    /// 여전히 이르면 다음 429 가 다시 잠근다.
    private func startSendCooldown() {
        cooldownTask?.cancel()
        sendCooldownNotice = "메시지를 너무 빠르게 보내고 있어요. 잠시 후 다시 시도해 주세요."
        cooldownTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.sendCooldown)
            guard !Task.isCancelled else { return }
            self?.sendCooldownNotice = nil
        }
    }

    /// 방이 사라진 경우. 알림을 먼저 띄우고, 확인을 누르면 리스트로 되돌린다.
    /// 이미 떠 있는 알림이 있으면 덮어쓰지 않는다 — 삭제와 강퇴가 겹쳐 와도 안내는 한 번이면 된다.
    private func eject(message: String) {
        guard alertPrompt == nil, !shouldDismiss else { return }
        alertPrompt = AlertPrompt(
            title: "스레드를 볼 수 없어요",
            message: message,
            positiveBtnTitle: "확인",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in self?.shouldDismiss = true }
            }
        )
    }

    private func updateMemberCount(_ memberCount: String) {
        guard var thread = header.value else { return }
        thread.memberCount = memberCount
        header = .loaded(thread)
    }

    private func optimisticMessage(clientMessageId: String, content: String) -> ThreadMessage {
        ThreadMessage(
            // 서버 messageId 를 아직 모른다. 교체 전까지는 clientMessageId 가 신원이다.
            id: clientMessageId,
            threadId: threadId,
            // TODO: currentMemberId 주입되면 발신자를 채운다 - [26.08.12] 정의진
            senderId: "",
            senderName: "",
            content: content,
            type: .text,
            files: [],
            mentions: [],
            replyTo: nil,
            reactions: [],
            clientMessageId: clientMessageId,
            createdAt: Date(),
            editedAt: nil,
            deletedAt: nil,
            deliveryState: .sending
        )
    }

    private func dispatch(clientMessageId: String, content: String) async {
        startTimeout(for: clientMessageId)

        do {
            try await useCase.send(
                threadId: threadId,
                clientMessageId: clientMessageId,
                content: content
            )
        } catch {
            // 프레임을 못 띄웠으면 서버 응답을 기다릴 이유가 없다. 전역 Alert 은 띄우지 않는다 —
            // 스펙 §7 이 전송 실패를 "버블 failed + 재전송 버튼" 으로 못박았고, `start()` 직후의
            // `notConnected` 는 정상 경로라 Alert 을 띄우면 첫 메시지마다 뜬다.
            markFailed(clientMessageId: clientMessageId)
        }
    }

    /// 응답이 오지 않는 경우를 닫는다. STOMP 는 SEND 에 대한 성공 응답이 없어 이 감시가 없으면
    /// `.sending` 스피너가 영원히 남는다.
    private func startTimeout(for clientMessageId: String) {
        pendingTimeouts[clientMessageId]?.cancel()
        pendingTimeouts[clientMessageId] = Task { [weak self, sendTimeout] in
            try? await Task.sleep(for: sendTimeout)
            guard !Task.isCancelled else { return }
            await self?.markFailed(clientMessageId: clientMessageId)
        }
    }

    private func markFailed(clientMessageId: String) {
        pendingTimeouts.removeValue(forKey: clientMessageId)?.cancel()
        // 이미 에코가 도착해 `.sent` 가 된 항목은 되돌리지 않는다. 전송 프레임의 실패와
        // 서버 확정이 겹치는 구간에서 이 가드가 유일한 방어다.
        guard let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }),
              messages[index].deliveryState == .sending else { return }
        messages[index].deliveryState = .failed
    }

    /// 서버 메시지를 목록에 반영한다.
    ///
    /// 재연결 백필과 실시간 수신이 겹치는 구간에서 같은 메시지가 두 경로로 들어온다.
    /// `messageId` 든 `clientMessageId` 든 하나만 걸리면 새로 넣지 않고 자리를 갈아 끼운다.
    private func insertOrReplace(_ message: ThreadMessage, clientMessageId: String?) {
        if let key = clientMessageId ?? message.clientMessageId {
            pendingTimeouts.removeValue(forKey: key)?.cancel()

            if let index = messages.firstIndex(where: { $0.clientMessageId == key }) {
                messages[index] = message.with(deliveryState: .sent)
                return
            }
        }

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message.with(deliveryState: .sent)
            return
        }

        messages.append(message.with(deliveryState: .sent))
    }

    private func sendWatermark(_ messageId: String) async {
        do {
            try await useCase.markRead(threadId: threadId, lastReadMessageId: messageId)
            lastSentWatermark = messageId
        } catch {
            // 읽음 영수증 실패는 사용자가 할 일이 없고, 연결 직전이면 `notConnected` 가 정상
            // 경로다. `lastSentWatermark` 를 올리지 않아 다음 스크롤이 같은 값을 다시 보낸다.
        }
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// 스크롤 한 번에 워터마크를 한 번만 보내기 위한 디바운스 (스펙 6.4).
    static let readWatermarkDebounce: Duration = .seconds(1)
    /// 서버가 남은 시간을 주지 않아 고정값으로 푼다.
    static let sendCooldown: Duration = .seconds(5)
}
