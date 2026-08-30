import SwiftUI
import CoreWatchDesignSystem

// MARK: - PingDetailView

/// The Ping 읽기 + 수신 확인.
///
/// 본문은 스크롤하고 확인 CTA 는 `.safeAreaInset(edge: .bottom)` 으로 **항상 화면에 남는다** —
/// 긴 공지에서 CTA 가 본문 끝까지 밀리면 「끝까지 스크롤해야 확인할 수 있는」 화면이 된다.
struct PingDetailView: View {

    // MARK: - Property

    /// 라우트가 식별자만 넘긴다. 본문은 수신함의 최신 스냅샷에서 매번 다시 찾는다 —
    /// 값을 복사해 들고 있으면 새 스냅샷이 도착해도 상세만 옛 내용으로 남는다.
    let noticeID: String

    @Environment(PingInbox.self) private var inbox

    private var item: WatchPingItem? { inbox.item(id: noticeID) }

    // MARK: - Body

    var body: some View {
        Group {
            if let item {
                body(of: item)
            } else {
                missingNotice
            }
        }
        .navigationTitle(WatchRoute.pingDetail(noticeID: noticeID).title)
        .navigationBarTitleDisplayMode(.inline)
        .watchScreenBackground()
    }

    // MARK: - Function

    private func body(of item: WatchPingItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchLayout.stackSpacing) {
                header(of: item)
                Text(item.content)
                    .font(.watch(.cardValue))
                    .foregroundStyle(WatchColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .safeAreaInset(edge: .bottom) {
            confirmation(of: item)
                .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
    }

    private func header(of item: WatchPingItem) -> some View {
        VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
            if item.isUrgent || item.isMustRead {
                signalBadges(of: item)
            }
            Text(item.title)
                .font(.watch(.screenTitle))
                .foregroundStyle(WatchColor.textPrimary)
                .multilineTextAlignment(.leading)
            Text("\(item.writer) · \(item.postedAt, format: .relative(presentation: .named))")
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 목록의 색바·오렌지 점은 여기서 **글자로** 다시 말한다. 상세에는 비교 대상 행이 없어
    /// 색·위치만으로는 무엇이 긴급인지 알 수 없다.
    private func signalBadges(of item: WatchPingItem) -> some View {
        HStack(spacing: WatchLayout.tightSpacing) {
            if item.isUrgent {
                WatchStatusBadge(.warning, label: Constants.urgentBadge)
            }
            if item.isMustRead {
                Text(Constants.mustReadBadge)
                    .font(.watch(.cardLabel))
                    .foregroundStyle(WatchColor.brandAccent)
            }
        }
    }

    @ViewBuilder
    private func confirmation(of item: WatchPingItem) -> some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            if item.isRead {
                WatchActionButton(
                    Constants.confirmedTitle,
                    systemImage: "checkmark",
                    disabledReason: Constants.confirmedReason
                ) {}
            } else {
                WatchActionButton(
                    Constants.confirmTitle,
                    role: .primary,
                    systemImage: "checkmark"
                ) {
                    inbox.confirmRead(noticeID: item.id)
                }
            }

            if let caption = confirmationCaption(of: item) {
                Text(caption.text)
                    .font(.watch(.caption))
                    .foregroundStyle(caption.color)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, WatchLayout.tightSpacing)
    }

    /// CTA 아래 한 줄. 실패가 있으면 실패를, 없고 연결이 끊겨 있으면 큐잉 안내를 말한다.
    ///
    /// 도달 불가는 **실패가 아니다** — 확인은 `transferUserInfo` 큐로 나가므로 연결이 끊겨
    /// 있어도 접수된다. 그 사실을 말해 주지 않으면 사용자가 확인을 다시 누르러 온다.
    private func confirmationCaption(of item: WatchPingItem) -> (text: String, color: Color)? {
        if let failure = inbox.confirmFailure, failure.noticeID == item.id {
            let text = failure.error.errorDescription ?? Constants.confirmFailed
            return (text, WatchColor.statusError)
        }
        if item.isRead {
            return nil
        }
        return inbox.isReachable
            ? nil
            : (Constants.queuedCaption, WatchColor.textSecondary)
    }

    /// 스냅샷에서 사라진 공지(삭제·목록 축소). 화면을 비우지 않고 사유를 말한다.
    private var missingNotice: some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            Text(Constants.missingTitle)
                .font(.watch(.screenTitle))
                .foregroundStyle(WatchColor.textPrimary)
            Text(Constants.missingDetail)
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, WatchLayout.screenHorizontalPadding)
    }
}

// MARK: - Constants

private enum Constants {
    static let urgentBadge = "긴급"
    static let mustReadBadge = "필수 확인"
    static let confirmTitle = "확인했습니다"
    static let confirmedTitle = "확인 완료"
    static let confirmedReason = "이미 확인한 공지입니다."
    static let confirmFailed = "확인을 보내지 못했습니다."
    static let queuedCaption = "iPhone 이 연결되면 전송됩니다."
    static let missingTitle = "공지를 찾을 수 없습니다"
    static let missingDetail = "iPhone 에서 삭제되었거나 목록에서 내려갔습니다."
}

#if DEBUG
#Preview("PingDetailView — 미확인 긴급") {
    NavigationStack {
        PingDetailView(noticeID: WatchPingItem.unreadUrgent.id)
    }
    .environment(PingInbox.preview(snapshot: .pingSample))
}

#Preview("PingDetailView — 확인 완료") {
    NavigationStack {
        PingDetailView(noticeID: WatchPingItem.read.id)
    }
    .environment(PingInbox.preview(snapshot: .pingSample))
}

#Preview("PingDetailView — A11y 크기") {
    NavigationStack {
        PingDetailView(noticeID: WatchPingItem.unreadUrgent.id)
    }
    .environment(PingInbox.preview(snapshot: .pingSample))
    .dynamicTypeSize(.accessibility3)
}
#endif
