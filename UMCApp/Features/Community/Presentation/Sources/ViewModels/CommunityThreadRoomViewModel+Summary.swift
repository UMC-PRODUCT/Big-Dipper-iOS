//
//  CommunityThreadRoomViewModel+Summary.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// 온디바이스 대화 요약.
///
/// 오래 비웠다 돌아온 방은 미읽음이 수십 개씩 쌓여 있어 처음부터 읽기가 부담스럽다. 그 구간만
/// 뽑아 핵심과 "내가 할 일" 로 줄여 주는 것이 이 확장의 일이다.
///
/// 요약 실패는 전역 Alert 으로 올리지 않는다 — 채팅은 그대로 쓸 수 있고 사용자가 할 수 있는
/// 선택은 "다시 요약" 하나뿐이라, 시트 안 인라인이 맞는 자리다 (스펙 §7 과 같은 결).
extension CommunityThreadRoomViewModel {

    // MARK: - Computed Property

    /// 배너를 띄울지.
    ///
    /// 미지원 기기에서는 폴백 안내조차 띄우지 않고 통째로 감춘다. 쓸 수 없는 기능을 알려 봐야
    /// 사용자가 할 수 있는 일이 없고, 채팅 화면 위 공간만 잡아먹는다.
    public var isSummaryBannerVisible: Bool {
        guard summarizer.isAvailable, !isSummaryBannerDismissed else { return false }
        return entryUnreadCount >= Constants.summaryBannerThreshold
    }

    /// 액션 아이템의 주인을 모델에 알려 줄 힌트.
    ///
    /// 세션에는 내 이름이 없고 메시지에는 있다. 이 방에서 내가 말한 적이 한 번도 없으면 넘길 값이
    /// 없어 `nil` 이다 — 그때는 요약만 나오고 액션 아이템이 비는 게 정상이다.
    var currentMemberName: String? {
        messages.last { isMine($0) && !$0.senderName.isEmpty }?.senderName
    }

    // MARK: - Function

    /// 진입 시점 미읽음 수를 한 번만 고정한다.
    ///
    /// 재연결 백필·강퇴 확정도 `header` 를 다시 쓰므로, 플래그 없이 스레드를 볼 때마다 갱신하면
    /// 이미 읽은 뒤에 0 으로 덮여 배너가 사라진다.
    func captureEntryUnreadCount(from thread: CommunityThread) {
        guard !hasCapturedEntryUnreadCount else { return }
        hasCapturedEntryUnreadCount = true
        entryUnreadCount = Int(thread.unreadCount) ?? 0
    }

    /// 미읽음 구간을 요약한다. 시트가 열릴 때와 재시도 버튼이 호출한다.
    public func requestSummary() async {
        guard !summary.isLoading else { return }
        summary = .loading

        do {
            let result = try await summarizer.summarize(
                messages: unreadMessages(),
                currentMemberName: currentMemberName
            )
            summary = .loaded(result)
        } catch {
            // 취소는 시트를 닫은 정상 흐름이다. 실패 화면으로 바꾸면 다시 열었을 때 에러부터
            // 보인다 (`load()` 와 같은 정책).
            guard !(error is CancellationError) else { return }
            summary = .failed(AppError.from(error))
        }
    }

    public func retrySummary() async {
        await requestSummary()
    }

    /// 시트를 닫을 때 결과를 버린다. 다시 열면 그 사이 쌓인 메시지까지 포함해 새로 요약한다.
    public func dismissSummary() {
        summary = .idle
    }

    public func dismissSummaryBanner() {
        isSummaryBannerDismissed = true
    }

    // MARK: - Private Function

    /// 요약에 넣을 구간. 배너가 약속한 "읽지 않은 N개" 와 실제 입력이 어긋나면 안 된다.
    ///
    /// 뒤에서 세는 이유는 미읽음이 항상 최신 쪽에 몰려 있기 때문이다. 화면에 아직 그만큼 안
    /// 쌓였으면 `suffix` 가 가진 만큼만 준다.
    private func unreadMessages() -> [ThreadMessage] {
        Array(messages.suffix(entryUnreadCount))
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// 배너를 띄우는 미읽음 하한.
    ///
    /// 명세에 수치가 없어 여기서 정한다. 서너 개짜리 대화는 스크롤로 훑는 편이 빠르고, 요약은
    /// 오히려 단계를 하나 더 만든다. 한 화면에 들어오는 버블이 대략 이 정도라 "한 화면을 넘게
    /// 밀렸다" 를 기준으로 잡았다.
    static let summaryBannerThreshold = 10
}
