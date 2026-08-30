import SwiftUI
import CoreWatchDesignSystem
import UMCFoundation

// MARK: - PingListView

/// The Ping 목록. 안읽음(점)과 긴급(좌측 색바)을 **서로 다른 축**으로 표시한다.
///
/// 행 배경은 `watchListRowBackground(isSelected:leadingAccent:)` 가 그리는 불투명 solid 다.
/// `List` 행은 Glass 금지 구역이라 Glass 배리언트를 쓰지 않는다.
struct PingListView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    @Environment(PingInbox.self) private var inbox

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle("The Ping")
            .watchScreenBackground()
            .task { await inbox.refresh() }
    }

    // MARK: - Function

    @ViewBuilder
    private var content: some View {
        switch inbox.state {
        case .idle, .loading:
            ProgressView()
                .tint(WatchColor.brandPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let items):
            if items.isEmpty {
                message(Constants.emptyTitle, detail: Constants.emptyDetail)
            } else {
                noticeList(items)
            }

        case .failed(let error):
            message(Constants.failureTitle, detail: error.errorDescription)
        }
    }

    private func noticeList(_ items: [WatchPingItem]) -> some View {
        List {
            if inbox.isShowingStaleSnapshot {
                staleCaption
            }

            ForEach(items) { item in
                Button {
                    router.push(.pingDetail(noticeID: item.id))
                } label: {
                    PingRow(item: item)
                }
                .buttonStyle(.plain)
                // 긴급 색바는 행 콘텐츠가 아니라 배경이 그린다 — 행 인셋 안쪽에 그리면
                // 가장자리에 닿지 않아 「좌측 바」로 읽히지 않는다.
                // 색은 `statusError` 다. 브랜드 오렌지는 안읽음 점 전용이라, 같은 색을 쓰면
                // 분리해야 할 두 신호가 한 색으로 뭉개진다.
                .watchListRowBackground(
                    leadingAccent: item.isUrgent ? WatchColor.statusError : nil
                )
                .accessibilityLabel(item.accessibilityLabel)
            }
        }
    }

    /// iPhone 과 연결되지 않아 마지막으로 받은 스냅샷을 그리는 중이라는 안내.
    /// 목록을 지우지 않고 캡션으로만 알린다 — 캐시가 있으면 읽을 수 있어야 한다.
    private var staleCaption: some View {
        Text(Constants.staleCaption)
            .font(.watch(.caption))
            .foregroundStyle(WatchColor.textSecondary)
            .listRowBackground(Color.clear)
    }

    private func message(_ title: String, detail: String?) -> some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            Text(title)
                .font(.watch(.screenTitle))
                .foregroundStyle(WatchColor.textPrimary)
            if let detail {
                Text(detail)
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, WatchLayout.screenHorizontalPadding)
    }
}

// MARK: - PingRow

/// 목록 한 행. 두 신호가 서로를 먹지 않도록 **점은 행 안쪽, 색바는 행 배경**에 둔다.
private struct PingRow: View {

    // MARK: - Property

    let item: WatchPingItem

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: WatchLayout.tightSpacing) {
            unreadDot
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                metaLine
                Text(item.title)
                    .font(.watch(.cardValue))
                    .foregroundStyle(titleColor)
                    .lineLimit(Constants.titleLineLimit)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, WatchLayout.tightSpacing)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Function

    /// 미확인 신호. 브랜드 오렌지 점이며 **읽은 행에는 점이 없다** — 색을 못 봐도 점의
    /// 유무(형태 차이)로 구분된다. 자리는 비워 두어 제목 좌측 정렬이 흔들리지 않게 한다.
    /// 낭독은 행 전체 `accessibilityLabel` 이 맡으므로 도형 자체는 낭독하지 않는다.
    @ViewBuilder
    private var unreadDot: some View {
        if item.isRead {
            Color.clear
                .frame(width: Constants.unreadDotSize, height: Constants.unreadDotSize)
        } else {
            Circle()
                .fill(WatchColor.brandAccent)
                .frame(width: Constants.unreadDotSize, height: Constants.unreadDotSize)
        }
    }

    private var metaLine: some View {
        HStack(spacing: WatchLayout.tightSpacing) {
            if item.isMustRead {
                Text(Constants.mustReadBadge)
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.brandAccent)
            }
            Text(item.postedAt, format: .relative(presentation: .named))
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
    }

    /// 읽은 공지는 한 단계 낮춰 미확인과 위계를 벌린다.
    private var titleColor: Color {
        item.isRead ? WatchColor.textSecondary : WatchColor.textPrimary
    }
}

// MARK: - Constants

private enum Constants {
    static let emptyTitle = "새 공지 없음"
    static let emptyDetail = "새 The Ping 이 오면 여기에 표시됩니다."
    static let failureTitle = "공지를 불러오지 못했습니다"
    static let staleCaption = "iPhone 연결 없음 · 마지막으로 받은 공지"
    static let mustReadBadge = "필수 확인"
    static let unreadDotSize: CGFloat = 7
    static let titleLineLimit = 3
}

#if DEBUG
#Preview("PingListView — 미확인·긴급·확인함") {
    NavigationStack {
        PingListView()
    }
    .environment(WatchRouter())
    .environment(PingInbox.preview(snapshot: .pingSample))
}

#Preview("PingListView — 빈 상태") {
    NavigationStack {
        PingListView()
    }
    .environment(WatchRouter())
    .environment(PingInbox.preview(snapshot: .pingEmpty))
}

#Preview("PingListView — A11y 크기") {
    NavigationStack {
        PingListView()
    }
    .environment(WatchRouter())
    .environment(PingInbox.preview(snapshot: .pingSample))
    .dynamicTypeSize(.accessibility3)
}
#endif
