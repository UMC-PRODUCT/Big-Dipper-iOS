//
//  CommunityThreadRoomViewModel+ThreadMenu.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// 채팅방 헤더 ⋯ 메뉴 (#1138).
///
/// 새 화면은 없다. #1134·#1135·#1136·#1137 이 이미 만들어 둔 진입점을 역할별로 묶어 한 자리에
/// 모으고, 리스트 스와이프에 있는 고정·알림·나가기에 삭제까지 방 안에서 쓰게 여는 것이 전부다.
///
/// 명령은 리스트 화면과 같은 ``CommunityThreadListUseCaseProtocol`` 로 보낸다 — 같은 REST 를
/// 부르는 계약을 화면마다 새로 파면 낙관적 갱신 규칙이 두 벌이 된다.
extension CommunityThreadRoomViewModel {

    // MARK: - Computed Property

    /// 스레드 편집·삭제를 열지. 리스트 스와이프와 같은 판정(`canEdit`)을 쓴다 (#1134).
    public var canEditThread: Bool {
        header.value?.canEdit == true
    }

    /// 운영 그룹을 통째로 그릴지. 일반 참여자에게는 항목이 하나도 남지 않아 구분선까지 감춘다.
    public var canManageThread: Bool {
        canInvite || canEditThread
    }

    /// 대화 요약을 열지. 지원하지 않는 기기에서는 항목을 비활성으로 남긴다 (#1137).
    public var canSummarize: Bool {
        summarizer.isAvailable
    }

    public var isPinned: Bool {
        header.value?.isPinned == true
    }

    public var isMuted: Bool {
        header.value?.isMuted == true
    }

    /// 공유 시트에 실을 링크. 서버 `shareURL` 이 우선이고, 없으면 딥링크로 대체한다 (#1142).
    public var shareLink: URL? {
        if let shareURL = header.value?.shareURL,
           let url = URL(string: shareURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return MessageLink.thread(id: threadId).url
    }

    // MARK: - Function

    /// 고정 토글. 리스트와 같은 낙관적 갱신 — 먼저 뒤집고 실패하면 되돌린다.
    public func togglePin() async {
        guard let target = updateThread({ $0.with(isPinned: !$0.isPinned) })?.isPinned else {
            return
        }

        do {
            try await listUseCase.togglePin(threadId: threadId, isPinned: target)
        } catch {
            updateThread { $0.with(isPinned: !target) }
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "togglePin"
            ))
        }
    }

    public func toggleMute() async {
        guard let target = updateThread({ $0.with(isMuted: !$0.isMuted) })?.isMuted else {
            return
        }

        do {
            try await listUseCase.toggleMute(threadId: threadId, isMuted: target)
        } catch {
            updateThread { $0.with(isMuted: !target) }
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "toggleMute"
            ))
        }
    }

    /// 나가기 확인. 문구·개설자 차단 규칙은 리스트 스와이프와 같아야 한다 (#1131 결정 2).
    public func confirmLeave() {
        guard let thread = header.value else { return }

        // 개설자는 위임 전까지 나갈 수 없다. 서버 409 를 알림으로 되돌려 주는 것보다 여기서 막고
        // 다음 행동을 알려 주는 편이 빠르다 — 위임은 참여자 목록의 ⋯ 메뉴에 있다.
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
                Task { await self?.leave() }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    /// 삭제 확인. 나가기와 달리 스레드 자체가 사라지므로 문구를 따로 쓴다 (#1134).
    public func confirmDeleteThread() {
        // 메뉴에 이미 권한 게이팅이 걸려 있지만, 서버 403 을 받기 전 마지막 방어선으로 본다.
        guard let thread = header.value, thread.canEdit else { return }

        alertPrompt = AlertPrompt(
            title: "'\(thread.title)' 스레드를 삭제할까요?",
            message: "대화 내용과 참여자가 모두 사라져요. 되돌릴 수 없어요.",
            positiveBtnTitle: "삭제",
            positiveBtnAction: { [weak self] in
                Task { await self?.deleteThread() }
            },
            negativeBtnTitle: "취소",
            isPositiveBtnDestructive: true
        )
    }

    // MARK: - Private

    /// 성공해야 화면을 닫는다. 실시간 `member.left` 는 내 것도 되돌아오지만 그건 확정이 아니다 —
    /// 실패한 요청까지 방을 닫아 버리면 아직 참여 중인 방에서 쫓겨난 것처럼 보인다.
    private func leave() async {
        do {
            try await listUseCase.leave(threadId: threadId)
            didLeave = true
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "leaveThread",
                retryAction: { [weak self] in await self?.leave() }
            ))
        }
    }

    private func deleteThread() async {
        do {
            try await listUseCase.deleteThread(threadId: threadId)
            didLeave = true
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "deleteThread",
                retryAction: { [weak self] in await self?.deleteThread() }
            ))
        }
    }
}
