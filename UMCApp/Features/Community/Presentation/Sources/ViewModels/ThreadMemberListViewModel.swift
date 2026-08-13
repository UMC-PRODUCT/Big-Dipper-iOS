//
//  ThreadMemberListViewModel.swift
//  CommunityPresentation
//

import Foundation
import Observation
import CommunityDomain
import UMCFoundation

/// 참여자 목록 상태 기계.
///
/// 내 권한은 세션이 아니라 **목록에 실려 온 내 행의 역할**에서 읽는다. 스레드 상세의
/// `myRole` 로도 알 수 있지만 위임 직후 두 값이 어긋나는 구간이 생긴다 — 방금 위임한 화면에서
/// 옛 권한으로 메뉴가 계속 열리는 게 그 증상이다.
@Observable
@MainActor
public final class ThreadMemberListViewModel {

    // MARK: - Property

    public private(set) var state: Loadable<[ThreadMember]> = .idle
    public var alertPrompt: AlertPrompt?
    /// 나가기가 확정된 상태. View 가 이걸 보고 커뮤니티 루트로 되돌린다.
    public private(set) var didLeave = false

    private let threadId: String
    private let useCase: CommunityThreadMemberUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let currentMemberId: String?

    // MARK: - Init

    /// - Parameter currentMemberId: 내 행을 가려 내는 유일한 열쇠. 없으면 관리 메뉴를 열지 않는다.
    public init(
        threadId: String,
        useCase: CommunityThreadMemberUseCaseProtocol,
        errorHandler: ErrorHandler,
        currentMemberId: String? = AppStorageKey.memberIdString()
    ) {
        self.threadId = threadId
        self.useCase = useCase
        self.errorHandler = errorHandler
        self.currentMemberId = currentMemberId
    }

    // MARK: - Computed Property

    public var members: [ThreadMember] { state.value ?? [] }

    /// 내가 개설자인지. 서버 역할이 유일한 근거라 목록을 받기 전에는 `false` 다.
    public var isOwner: Bool {
        members.first { isMe($0.id) }?.role == .owner
    }

    /// 나가기를 막는 이유. `nil` 이면 나갈 수 있다.
    ///
    /// #1131 결정 2 — 개설자는 위임 전까지 나갈 수 없다. 위임할 상대조차 없으면 나가기가 아니라
    /// 스레드 삭제가 정답이라 안내 문구를 나눈다.
    public var leaveBlockReason: String? {
        guard isOwner else { return nil }
        return members.contains { !isMe($0.id) }
            ? Constants.delegateFirstReason
            : Constants.deleteInsteadReason
    }

    /// 나가기 버튼 활성 조건. 목록을 받기 전에는 내 역할을 모르므로 잠가 둔다.
    public var canLeave: Bool {
        state.value != nil && leaveBlockReason == nil
    }

    // MARK: - Function

    public func load() async {
        state = .loading
        do {
            state = .loaded(try await useCase.loadMembers(threadId: threadId))
        } catch {
            // 취소는 화면을 떠난 정상 흐름이다. 에러 화면으로 바꾸면 안 된다.
            guard !(error is CancellationError) else { return }
            state = .failed(AppError.from(error))
        }
    }

    /// 내 행인지. "(나)" 표시와 관리 메뉴 판정이 같은 기준을 봐야 한다.
    public func isMe(_ member: ThreadMember) -> Bool {
        isMe(member.id)
    }

    /// 행의 ⋯ 메뉴를 열지. 개설자만, 그리고 내 행에는 열지 않는다 —
    /// 자기를 내보내거나 자기에게 위임하는 조합은 서버도 거절한다.
    public func canManage(_ member: ThreadMember) -> Bool {
        isOwner && !isMe(member.id)
    }

    /// 내보내기 확인. 되돌릴 수 없어 재초대 조건까지 알린다 (시안 #37).
    public func confirmKick(_ member: ThreadMember) {
        guard canManage(member) else { return }

        alertPrompt = AlertPrompt(
            title: "\(member.name) 님을 내보낼까요?",
            message: "내보낸 참여자는 다시 초대해야 참여할 수 있어요.",
            positiveBtnTitle: "내보내기",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.kick(member) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 개설자 위임 확인. 내 권한을 넘기는 비가역 작업이라 한 번 묻는다.
    public func confirmTransferOwnership(to member: ThreadMember) {
        guard canManage(member) else { return }

        alertPrompt = AlertPrompt(
            title: "\(member.name) 님에게 개설자를 위임할까요?",
            message: "위임하면 되돌릴 수 없고, 나는 일반 참여자가 돼요.",
            positiveBtnTitle: "위임",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.transferOwnership(to: member) }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 나가기 확인. 재참여 조건을 함께 알린다 (시안 #30).
    public func confirmLeave() {
        guard canLeave else { return }

        alertPrompt = AlertPrompt(
            title: "스레드를 나갈까요?",
            message: "나가면 대화 내용을 볼 수 없고, 다시 참여하려면 초대를 받아야 해요.",
            positiveBtnTitle: "나가기",
            positiveBtnAction: { [weak self] in
                Task { @MainActor in await self?.leave() }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Private Function

    private func isMe(_ memberId: String) -> Bool {
        guard let currentMemberId, !currentMemberId.isEmpty else { return false }
        return memberId == currentMemberId
    }

    /// 먼저 지워 놓고 보낸다. 실패하면 스냅샷으로 되돌린다 — 목록에서 사라진 사람이 다시
    /// 나타나는 편이, 서버에 남아 있는 사람이 없는 것처럼 보이는 것보다 낫다.
    private func kick(_ member: ThreadMember) async {
        let snapshot = state
        state = .loaded(members.filter { $0.id != member.id })

        do {
            try await useCase.kick(threadId: threadId, memberId: member.id)
        } catch {
            state = snapshot
            errorHandler.handle(error, context: errorContext("kickThreadMember"))
        }
    }

    /// 위임은 내 역할까지 함께 바꾼다. 성공 뒤 서버 값을 다시 읽는 이유는, 이전 개설자를
    /// `ADMIN` 으로 둘지 `MEMBER` 로 둘지가 서버 정책이라 클라이언트가 추측하면 배지가 어긋나서다.
    private func transferOwnership(to member: ThreadMember) async {
        do {
            try await useCase.transferOwnership(threadId: threadId, to: member.id)
            await load()
        } catch {
            errorHandler.handle(error, context: errorContext("transferThreadOwnership"))
        }
    }

    /// 개설자 차단은 버튼에서 이미 걸리지만, 서버 409 를 받기 전 마지막 방어선으로 한 번 더 본다.
    private func leave() async {
        guard canLeave else { return }

        do {
            try await useCase.leave(threadId: threadId)
            didLeave = true
        } catch {
            errorHandler.handle(error, context: errorContext("leaveThread"))
        }
    }

    private func errorContext(_ action: String) -> ErrorContext {
        ErrorContext(
            feature: "Community",
            action: action,
            retryAction: { [weak self] in await self?.load() }
        )
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let delegateFirstReason = "먼저 다른 참여자에게 개설자를 위임해 주세요."
    static let deleteInsteadReason = "참여자가 나뿐이라 위임할 상대가 없어요. 스레드를 삭제해 주세요."
}
