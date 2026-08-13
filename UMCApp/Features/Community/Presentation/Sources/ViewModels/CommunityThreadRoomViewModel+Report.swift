//
//  CommunityThreadRoomViewModel+Report.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain
import UMCFoundation

/// 메시지 신고 접수.
///
/// 이 확장이 하는 일은 접수까지다 — 신고가 쌓였다고 메시지를 감추거나 임계값을 세지 않는다
/// (#1131 결정 4). 소수의 담합으로 정상 메시지를 지울 수 있는 경로를 클라이언트에 두지 않고,
/// 이후 처리는 운영진이 수동으로 확인한다.
///
/// 접수 실패는 전역 Alert 이 아니라 시트 안 인라인이다 — 사용자가 고른 사유를 잃지 않고 그
/// 자리에서 다시 누르면 되는 실패라 흐름을 끊을 이유가 없다 (`+Summary` 와 같은 결).
extension CommunityThreadRoomViewModel {

    // MARK: - Function

    /// 신고 메뉴를 띄울지. 내 메시지는 신고 대상이 아니고, 톰스톤은 신고할 본문이 없다.
    ///
    /// 아직 서버가 모르는 메시지(`.sending`/`.failed`)의 id 는 내가 만든 UUID 라 보내 봐야
    /// 거절당한다 — `canDelete` 와 같은 이유로 막는다.
    public func canReport(_ message: ThreadMessage) -> Bool {
        guard !message.isDeleted, message.deliveryState == .sent else { return false }
        return !isMine(message)
    }

    /// 컨텍스트 메뉴의 "신고" 진입점.
    ///
    /// 이미 접수한 메시지는 시트를 열지 않고 이유만 알려 준다 — 사유를 다시 고르게 해 놓고
    /// 마지막에 거절하면 고른 시간을 통째로 버리게 된다.
    public func requestReport(_ message: ThreadMessage) {
        guard canReport(message) else { return }

        guard !reportedMessageIds.contains(message.id) else {
            showReportNotice(Constants.duplicateNotice)
            return
        }

        reportState = .idle
        reportTarget = message
    }

    /// 사유 시트의 "신고하기".
    ///
    /// 성공하면 시트를 닫고 완료 문구를 띄운다. 실패는 시트를 열어 둔 채 인라인으로 남긴다.
    public func submitReport(reason: ThreadMessageReportReason) async {
        guard let message = reportTarget, !reportState.isLoading else { return }

        reportState = .loading

        do {
            try await useCase.reportMessage(messageId: message.id, reason: reason)
            reportedMessageIds.insert(message.id)
            reportState = .loaded(reason)
            reportTarget = nil
            showReportNotice(Constants.successNotice)
        } catch {
            reportState = .failed(AppError.from(error))
        }
    }

    /// 시트를 닫을 때 남은 실패 문구를 버린다 — 다시 열었을 때 지난 에러부터 보이면 안 된다.
    public func dismissReport() {
        reportTarget = nil
        reportState = .idle
    }

    // MARK: - Private Function

    /// 잠깐 띄웠다 스스로 사라지는 안내. 확인을 누를 것이 없어 Alert 을 쓰지 않는다.
    private func showReportNotice(_ notice: String) {
        reportNoticeTask?.cancel()
        reportNotice = notice
        reportNoticeTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.noticeDuration)
            guard !Task.isCancelled else { return }
            self?.reportNotice = nil
        }
    }
}

// MARK: - Constants

fileprivate enum Constants {
    static let successNotice = "신고를 접수했어요. 운영진이 확인할게요."
    static let duplicateNotice = "이미 신고한 메시지예요. 접수된 신고는 운영진이 확인 중이에요."
    /// 읽고 사라지기에 충분한 길이. 안내를 놓쳐도 잃는 것이 없어 더 붙잡아 둘 이유가 없다.
    static let noticeDuration: Duration = .seconds(3)
}
