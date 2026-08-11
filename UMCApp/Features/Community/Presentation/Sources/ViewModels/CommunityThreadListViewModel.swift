//
//  CommunityThreadListViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 커뮤니티 스레드 리스트 상태 기계.
///
/// 서버가 고정 스레드를 별도 배열로 주고 페이징 대상에서 빼기 때문에 `pinned` 를 `state` 와
/// 분리해 들고 있다. 검색 모드에서는 서버가 `pinned` 를 비워 보내므로 자연히 한 섹션만 남는다.
///
/// 실시간 이벤트는 스레드별 topic 이 아니라 **유저 단위 팬아웃**으로 온다. 즉 같은 스레드에
/// 남아 있는 다른 멤버의 이벤트도 내 큐로 들어오므로, `memberId` 를 가릴 수 없는 이벤트는
/// 낙관적으로 반영하지 않고 REST 최종 상태에 맡긴다.
@Observable
@MainActor
public final class CommunityThreadListViewModel {

    // MARK: - Property

    public private(set) var state: Loadable<[CommunityThread]> = .idle
    public private(set) var pinned: [CommunityThread] = []
    public private(set) var isLoadingNextPage = false

    public var alertPrompt: AlertPrompt?

    public var filter: CommunityThreadFilter = .all {
        didSet {
            guard filter != oldValue else { return }
            reloadTask?.cancel()
            reloadTask = Task { [weak self] in await self?.load() }
        }
    }

    /// 타이핑마다 호출하면 서버가 낭비된다. 300ms 멈춘 뒤에만 조회한다.
    public var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            reloadTask?.cancel()
            reloadTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await self?.load()
            }
        }
    }

    private let listUseCase: CommunityThreadListUseCaseProtocol
    private let roomUseCase: CommunityThreadRoomUseCaseProtocol?
    private let errorHandler: ErrorHandler

    @ObservationIgnored private var nextOffset: Int?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameter roomUseCase: 실시간 신호 구독용. 테스트에서는 `nil` 을 넣어 STOMP 를 뺀다.
    public init(
        listUseCase: CommunityThreadListUseCaseProtocol,
        roomUseCase: CommunityThreadRoomUseCaseProtocol?,
        errorHandler: ErrorHandler
    ) {
        self.listUseCase = listUseCase
        self.roomUseCase = roomUseCase
        self.errorHandler = errorHandler
    }

    // MARK: - Computed Property

    private var trimmedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Function

    public func load() async {
        state = .loading
        nextOffset = nil
        // 진행 중인 페이징이 있으면 그 응답은 아래 staleness 검사에서 버려진다.
        isLoadingNextPage = false

        let requestedFilter = filter
        let requestedQuery = trimmedQuery

        do {
            let page = try await listUseCase.loadThreads(
                filter: requestedFilter,
                query: requestedQuery,
                offset: 0
            )
            guard !isStale(requestedFilter, requestedQuery) else { return }
            pinned = page.pinned
            state = .loaded(page.threads)
            nextOffset = page.nextOffset.flatMap(Int.init)
        } catch {
            // 취소는 사용자가 만든 정상 흐름이다. AppError.from 은 이걸 몰라 .unknown 으로 떨군다.
            guard !(error is CancellationError),
                  !isStale(requestedFilter, requestedQuery) else { return }
            state = .failed(AppError.from(error))
        }
    }

    /// 당겨서 새로고침. 목록이 잠깐 비는 걸 막으려고 `.loading` 으로 되돌리지 않는다.
    public func refresh() async {
        let requestedFilter = filter
        let requestedQuery = trimmedQuery

        do {
            let page = try await listUseCase.loadThreads(
                filter: requestedFilter,
                query: requestedQuery,
                offset: 0
            )
            guard !isStale(requestedFilter, requestedQuery) else { return }
            pinned = page.pinned
            state = .loaded(page.threads)
            nextOffset = page.nextOffset.flatMap(Int.init)
        } catch {
            guard !(error is CancellationError) else { return }
            errorHandler.handle(error, context: errorContext("refreshThreads"))
        }
    }

    /// 마지막 행이 보이면 다음 페이지를 붙인다.
    public func loadNextPageIfNeeded(currentItem: CommunityThread) async {
        guard let offset = nextOffset,
              !isLoadingNextPage,
              let threads = state.value,
              threads.last?.id == currentItem.id else { return }

        let requestedFilter = filter
        let requestedQuery = trimmedQuery

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await listUseCase.loadThreads(
                filter: requestedFilter,
                query: requestedQuery,
                offset: offset
            )
            guard !isStale(requestedFilter, requestedQuery), !Task.isCancelled else { return }

            // await 이전 스냅샷을 쓰면 그 사이 도착한 실시간 갱신이 통째로 되살아난다.
            let current = state.value ?? []
            let currentIds = Set(current.map(\.id))
            state = .loaded(current + page.threads.filter { !currentIds.contains($0.id) })
            nextOffset = page.nextOffset.flatMap(Int.init)
        } catch {
            guard !(error is CancellationError),
                  !isStale(requestedFilter, requestedQuery) else { return }
            errorHandler.handle(error, context: errorContext("loadNextThreadPage"))
        }
    }

    /// 고정 토글. 스와이프 즉시 자리를 옮기고, 실패하면 되돌린다.
    public func togglePin(_ thread: CommunityThread) async {
        let target = !thread.isPinned
        let snapshotState = state
        let snapshotPinned = pinned
        movePin(threadId: thread.id, isPinned: target)

        do {
            try await listUseCase.togglePin(threadId: thread.id, isPinned: target)
        } catch {
            // 반대 방향 이동으로 되돌리면 원래 인덱스를 잃어 20번째 행이 최상단에 박힌다.
            state = snapshotState
            pinned = snapshotPinned
            errorHandler.handle(error, context: errorContext("togglePin"))
        }
    }

    public func toggleMute(_ thread: CommunityThread) async {
        let target = !thread.isMuted
        updateRow(threadId: thread.id) { $0.with(isMuted: target) }

        do {
            try await listUseCase.toggleMute(threadId: thread.id, isMuted: target)
        } catch {
            updateRow(threadId: thread.id) { $0.with(isMuted: !target) }
            errorHandler.handle(error, context: errorContext("toggleMute"))
        }
    }

    /// 나가기는 되돌릴 수 없어 확인을 먼저 받는다 (절대 규칙 — 파괴적 작업은 AlertPrompt).
    public func confirmLeave(_ thread: CommunityThread) {
        alertPrompt = AlertPrompt(
            title: "스레드 나가기",
            message: "'\(thread.title)' 에서 나가면 대화 내용을 볼 수 없어요.",
            positiveBtnTitle: "나가기",
            positiveBtnAction: { [weak self] in
                Task { await self?.leave(thread) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 실시간 신호 구독. 화면이 사라지면 `task` 취소로 함께 끝난다.
    public func observeRealtime() async {
        guard let roomUseCase else { return }

        await roomUseCase.startRealtime()
        let signals = await roomUseCase.signals()

        for await signal in signals {
            switch signal {
            case .event(let event):
                apply(event)
            case .reconnected:
                // 끊긴 동안의 이벤트는 재생되지 않는다. 목록 전체를 다시 읽는 게 유일한 정답이다.
                await refresh()
            case .commandFailed:
                break
            }
        }
    }

    /// 실시간 이벤트를 목록에 반영한다. 테스트가 직접 호출할 수 있게 열어 둔다.
    func apply(_ event: CommunityThreadRealtimeEvent) {
        switch event {
        case .messageCreated(let threadId, let message, _):
            updateRow(threadId: threadId) { thread in
                var updated = thread
                updated.lastMessage = ThreadLastMessage(
                    preview: message.content,
                    senderName: message.senderName,
                    createdAt: message.createdAt
                )
                updated.unreadCount = String((Int(thread.unreadCount) ?? 0) + 1)
                return updated
            }

        case .readUpdated:
            // 남의 읽음 영수증도 내 큐로 온다. memberId 를 가리지 못한 채 0 으로 내리면
            // 안 읽은 배지가 조용히 사라진다. 0 처리는 채팅방 진입 시 로컬로 하고
            // 정정은 REST 조회에 맡긴다 (설계 스펙 10장 "unreadCount 갱신 주체" 잠정 정책).
            // TODO: currentMemberId 주입되면 내 영수증일 때만 0 처리 - [26.08.12] 정의진
            break

        case .threadUpdated(let update):
            updateRow(threadId: update.threadId) { thread in
                var updated = thread
                updated.title = update.title
                updated.description = update.description
                updated.category = update.category
                updated.icon = update.icon
                updated.memberCount = update.memberCount
                return updated
            }

        case .threadInvited(let thread):
            guard let threads = state.value,
                  !threads.contains(where: { $0.id == thread.id }) else { return }
            state = .loaded([thread] + threads)

        case .threadDeleted(let threadId, _):
            removeRow(threadId: threadId)

        case .memberKicked(let threadId, _, let memberCount):
            // 팬아웃 대상이 나인지 남은 멤버인지 이벤트만으로 못 가른다. 무조건 지우면 남이
            // 강퇴당했을 때 모두의 목록에서 스레드가 사라진다. 카운트만 반영하고 최종 상태는
            // REST 로 확정한다 (강퇴는 드물어 재조회 비용이 무시할 만하다).
            // TODO: currentMemberId 주입되면 memberId 비교로 대체 - [26.08.12] 정의진
            updateRow(threadId: threadId) { thread in
                var updated = thread
                updated.memberCount = memberCount
                return updated
            }
            Task { [weak self] in await self?.refresh() }

        case .memberLeft(let threadId, _, let memberCount):
            updateRow(threadId: threadId) { thread in
                var updated = thread
                updated.memberCount = memberCount
                return updated
            }

        case .commandAcknowledged, .messageUpdated, .messageDeleted,
             .reactionChanged, .unknown:
            break
        }
    }

    // MARK: - Private Function

    /// 응답이 도착했을 때 사용자가 이미 다른 필터·검색어로 옮겨갔는지.
    ///
    /// `Task.isCancelled` 로는 부족하다 — View 의 `.task` 나 페이징이 띄운 Task 는 필터 변경으로
    /// 취소되지 않아서, 늦게 도착한 이전 조건의 응답이 현재 화면을 덮어쓴다.
    private func isStale(
        _ requestedFilter: CommunityThreadFilter,
        _ requestedQuery: String?
    ) -> Bool {
        requestedFilter != filter || requestedQuery != trimmedQuery
    }

    private func errorContext(_ action: String) -> ErrorContext {
        ErrorContext(
            feature: "Community",
            action: action,
            retryAction: { [weak self] in await self?.refresh() }
        )
    }

    private func leave(_ thread: CommunityThread) async {
        let snapshotState = state
        let snapshotPinned = pinned
        removeRow(threadId: thread.id)

        do {
            try await listUseCase.leave(threadId: thread.id)
        } catch {
            state = snapshotState
            pinned = snapshotPinned
            errorHandler.handle(error, context: errorContext("leaveThread"))
        }
    }

    /// 두 섹션 어느 쪽에 있든 찾아서 바꾼다.
    private func updateRow(
        threadId: String,
        transform: (CommunityThread) -> CommunityThread
    ) {
        if let index = pinned.firstIndex(where: { $0.id == threadId }) {
            pinned[index] = transform(pinned[index])
        }
        guard var threads = state.value,
              let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
        threads[index] = transform(threads[index])
        state = .loaded(threads)
    }

    private func removeRow(threadId: String) {
        pinned.removeAll { $0.id == threadId }
        guard var threads = state.value else { return }
        threads.removeAll { $0.id == threadId }
        state = .loaded(threads)
    }

    /// 고정 ↔ 일반 섹션 이동. 서버는 두 배열을 나눠 주므로 클라이언트도 옮겨 담아야 한다.
    private func movePin(threadId: String, isPinned: Bool) {
        guard var threads = state.value else { return }

        if isPinned {
            guard let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
            pinned.append(threads.remove(at: index).with(isPinned: true))
        } else {
            guard let index = pinned.firstIndex(where: { $0.id == threadId }) else { return }
            threads.insert(pinned.remove(at: index).with(isPinned: false), at: 0)
        }
        state = .loaded(threads)
    }
}
