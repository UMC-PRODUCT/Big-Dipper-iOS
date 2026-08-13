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
    /// 최신순 최근 검색어. 검색 필드를 열었을 때만 화면에 나온다.
    public private(set) var recentSearches: [String] = []

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
    private let currentMemberId: String?

    @ObservationIgnored private let recentSearchStore: RecentThreadSearchStore
    @ObservationIgnored private var nextOffset: Int?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameters:
    ///   - roomUseCase: 실시간 신호 구독용. 테스트에서는 `nil` 을 넣어 STOMP 를 뺀다.
    ///   - currentMemberId: 팬아웃으로 도착한 이벤트가 나를 겨눈 것인지 가르는 유일한 열쇠.
    ///   - recentSearchStore: 최근 검색어 로컬 저장소. 테스트에서 격리 suite 를 주입한다.
    public init(
        listUseCase: CommunityThreadListUseCaseProtocol,
        roomUseCase: CommunityThreadRoomUseCaseProtocol?,
        errorHandler: ErrorHandler,
        currentMemberId: String? = AppStorageKey.memberIdString(),
        recentSearchStore: RecentThreadSearchStore = RecentThreadSearchStore()
    ) {
        self.listUseCase = listUseCase
        self.roomUseCase = roomUseCase
        self.errorHandler = errorHandler
        self.currentMemberId = currentMemberId
        self.recentSearchStore = recentSearchStore
        self.recentSearches = recentSearchStore.load()
    }

    // MARK: - Computed Property

    /// 지금 조회에 쓰이는 검색어. `nil` 이면 검색 중이 아니다.
    public var trimmedQuery: String? {
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
    ///
    /// - Parameter silent: 실패해도 전역 Alert 을 띄우지 않는다. 재연결처럼 사용자가 시작하지
    ///   않은 재조회에만 쓴다 — 지하철에서 재연결이 세 번 튀면 Alert 도 세 번 뜬다 (스펙 §7).
    public func refresh(silent: Bool = false) async {
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
            guard !(error is CancellationError), !silent else { return }
            errorHandler.handle(error, context: errorContext("refreshThreads"))
        }
    }

    // MARK: - Search

    /// 최근 검색어를 눌렀을 때. 검색어를 채우면 `searchText` 의 디바운스가 조회까지 이어간다.
    public func applyRecentSearch(_ term: String) {
        recentSearches = recentSearchStore.add(term)
        searchText = term
    }

    /// 검색어를 확정했을 때만 기록한다.
    ///
    /// 디바운스 조회마다 기록하면 `스`·`스터`·`스터디` 가 나란히 쌓인다. 키보드 검색 버튼과
    /// 결과 행 진입(= 원하는 걸 찾았다는 신호) 두 지점에서만 부른다.
    public func recordCurrentSearch() {
        guard let query = trimmedQuery else { return }
        recentSearches = recentSearchStore.add(query)
    }

    public func removeRecentSearch(_ term: String) {
        recentSearches = recentSearchStore.remove(term)
    }

    public func clearRecentSearches() {
        recentSearches = recentSearchStore.clear()
    }

    /// 결과 없음 빈 상태의 `검색어 지우기`. 원래의 고정/전체 2섹션 목록으로 되돌아간다.
    public func clearSearch() {
        searchText = ""
    }

    // MARK: - Function

    /// 채팅방에 들어간 순간 그 행의 미읽음 배지를 로컬로 내린다.
    ///
    /// 서버가 `read.updated` 를 본인에게도 echo 하는지 미확정이라 이벤트로는 0 을 만들 수 없다.
    /// 방 VM 이 보낸 워터마크가 서버에 닿으면 다음 REST 조회가 이 값을 정정한다 (스펙 §10).
    public func markThreadRead(threadId: String) {
        updateRow(threadId: threadId) { thread in
            var updated = thread
            updated.unreadCount = "0"
            return updated
        }
    }

    /// 방금 만든 스레드를 목록 맨 위에 꽂는다.
    ///
    /// 서버는 개설자에게 실시간 이벤트를 쏘지 않으므로(`thread.invited` 는 초대된 멤버 전용)
    /// 생성 화면이 직접 알려 주는 이 경로가 유일하다. `.threadInvited` 와 같은 이유로 중복은
    /// 건너뛴다 — 재조회가 먼저 도착했을 수 있다.
    public func insertCreated(_ thread: CommunityThread) {
        let threads = state.value ?? []
        guard !threads.contains(where: { $0.id == thread.id }) else { return }
        state = .loaded([thread] + threads)
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

    /// 다른 화면에서 나가기·삭제가 확정됐을 때 행을 지운다.
    public func removeThread(threadId: String) {
        removeRow(threadId: threadId)
    }

    /// 편집 화면이 돌려준 값을 행에 반영한다.
    ///
    /// 응답 전체로 행을 갈아 끼우지 않고 편집 대상 4개만 옮긴다 — 상세 응답의 `unreadCount`·
    /// `lastMessage` 로 덮으면 리스트가 로컬로 내려 둔 배지가 되살아난다 (`.threadUpdated` 와 동일).
    public func applyUpdated(_ thread: CommunityThread) {
        updateRow(threadId: thread.id) { row in
            var updated = row
            updated.title = thread.title
            updated.description = thread.description
            updated.category = thread.category
            updated.icon = thread.icon
            return updated
        }
    }

    /// 채팅방 ⋯ 메뉴에서 바꾼 고정·알림을 행에 반영한다 (#1138).
    ///
    /// `applyUpdated` 에 얹지 않는다 — 그쪽은 편집 화면이 고친 4개 필드 전용이고, 고정은 섹션
    /// 이동까지 따라야 해서 갱신 방법이 아예 다르다. 이미 그 상태인 행은 `movePin` 이 넘긴다.
    public func applyToggles(_ thread: CommunityThread) {
        movePin(threadId: thread.id, isPinned: thread.isPinned)
        updateRow(threadId: thread.id) {
            $0.with(isPinned: thread.isPinned, isMuted: thread.isMuted)
        }
    }

    /// 스와이프 삭제 확인. 나가기와 달리 스레드 자체가 사라지므로 문구를 따로 쓴다 (#1134).
    public func confirmDelete(_ thread: CommunityThread) {
        // 스와이프에 이미 권한 게이팅이 걸려 있지만, 서버 403 을 받기 전 마지막 방어선으로 본다.
        guard thread.canEdit else { return }

        alertPrompt = AlertPrompt(
            title: "'\(thread.title)' 스레드를 삭제할까요?",
            message: "대화 내용과 참여자가 모두 사라져요. 되돌릴 수 없어요.",
            positiveBtnTitle: "삭제",
            positiveBtnAction: { [weak self] in
                Task { await self?.delete(thread) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 나가기는 되돌릴 수 없어 확인을 먼저 받는다 (절대 규칙 — 파괴적 작업은 AlertPrompt).
    public func confirmLeave(_ thread: CommunityThread) {
        // #1131 결정 2: 개설자는 위임 전까지 나갈 수 없다. 서버 409 를 알림으로 되돌려 주는 것보다
        // 여기서 막고 다음 행동을 알려 주는 편이 빠르다 — 위임은 참여자 목록의 ⋯ 메뉴에 있다.
        guard thread.myRole != .owner else {
            alertPrompt = AlertPrompt(
                title: "개설자는 바로 나갈 수 없어요",
                message: "먼저 참여자 목록에서 다른 참여자에게 개설자를 위임해 주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        alertPrompt = AlertPrompt(
            title: "스레드 나가기",
            message: """
                '\(thread.title)' 에서 나가면 대화 내용을 볼 수 없어요. \
                다시 참여하려면 초대를 받아야 해요.
                """,
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
                await refresh(silent: true)
            case .commandFailed:
                break
            }
        }
    }

    /// 실시간 이벤트를 목록에 반영한다. 테스트가 직접 호출할 수 있게 열어 둔다.
    func apply(_ event: CommunityThreadRealtimeEvent) {
        switch event {
        case .messageCreated(let threadId, let message, _):
            // 내가 보낸 메시지도 팬아웃으로 되돌아온다. 그것까지 세면 지금 보고 있는 방의
            // 배지가 내 손으로 올라간다.
            let countsAsUnread = !isMe(message.senderId)
            updateRow(threadId: threadId) { thread in
                var updated = thread
                updated.lastMessage = ThreadLastMessage(
                    preview: message.content,
                    senderName: message.senderName,
                    createdAt: message.createdAt
                )
                if countsAsUnread {
                    updated.unreadCount = String((Int(thread.unreadCount) ?? 0) + 1)
                }
                return updated
            }

        case .readUpdated:
            // 남의 읽음 영수증도 내 큐로 온다. 서버가 본인에게도 echo 하는지 미확정이라
            // memberId 게이팅을 믿을 수 없다. 0 처리는 방 진입 시 `markThreadRead` 가 로컬로
            // 하고, 정정은 REST 조회에 맡긴다 (설계 스펙 10장 "unreadCount 갱신 주체").
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
            guard hasRow(threadId: threadId) else { return }
            updateRow(threadId: threadId) { thread in
                var updated = thread
                updated.memberCount = memberCount
                return updated
            }
            Task { [weak self] in await self?.refresh(silent: true) }

        case .memberLeft(let threadId, let memberId, let memberCount):
            // 나간 게 나라면 다른 기기·웹에서 벌어진 일이다. 강퇴와 달리 팬아웃 모호성이 없어
            // 재조회 없이 바로 지운다 (스펙 §6.1 "member.left → 행 제거").
            guard !isMe(memberId) else {
                removeRow(threadId: threadId)
                return
            }
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

    /// 이벤트가 지목한 멤버가 나인지. 세션에 memberId 가 없으면 가릴 수 없으므로 남으로 본다 —
    /// 잘못 "나" 로 판정하면 남의 이벤트로 내 행이 사라진다.
    private func isMe(_ memberId: String) -> Bool {
        guard let currentMemberId, !currentMemberId.isEmpty else { return false }
        return memberId == currentMemberId
    }

    private func hasRow(threadId: String) -> Bool {
        pinned.contains(where: { $0.id == threadId })
            || state.value?.contains(where: { $0.id == threadId }) == true
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

    /// 나가기와 같은 낙관적 제거. 실패하면 스냅샷으로 되돌린다.
    private func delete(_ thread: CommunityThread) async {
        let snapshotState = state
        let snapshotPinned = pinned
        removeRow(threadId: thread.id)

        do {
            try await listUseCase.deleteThread(threadId: thread.id)
        } catch {
            state = snapshotState
            pinned = snapshotPinned
            errorHandler.handle(error, context: errorContext("deleteThread"))
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
