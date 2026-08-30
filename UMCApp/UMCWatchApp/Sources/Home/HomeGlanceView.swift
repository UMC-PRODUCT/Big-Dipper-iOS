import SwiftUI
import CoreWatchDesignSystem

// MARK: - HomeGlanceView

/// 홈 통합 글랜스. 오늘 세션·The Ping·승인 대기를 한 화면에서 훑고 각 플로우로 진입한다.
struct HomeGlanceView: View {

    // MARK: - Property

    @Environment(WatchRouter.self) private var router
    @State private var viewModel: HomeGlanceViewModel

    // MARK: - Init

    init(glance: WatchGlance = .empty) {
        _viewModel = State(initialValue: HomeGlanceViewModel(glance: glance))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchLayout.stackSpacing) {
                attendanceChip
                pingChip
                pendingApprovalBadge
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .navigationTitle("홈")
        .watchScreenBackground()
    }

    // MARK: - Function

    /// 세션 카드 전체가 출석 플로우 진입점이다. `.plain` 이어야 카드 표면이 solid 로 남는다 —
    /// Glass 버튼 스타일을 쓰면 카드가 Glass 금지 구역을 침범한다.
    private var attendanceChip: some View {
        Button {
            router.push(viewModel.attendanceRoute)
        } label: {
            sessionCard
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sessionCard: some View {
        if let session = viewModel.glance.session {
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                cardLabel("오늘 세션")
                Text(session.startsAt, format: .dateTime.hour().minute())
                    .font(.watch(.metric))
                    .foregroundStyle(WatchColor.textPrimary)
                Text(session.title)
                    .font(.watch(.cardValue))
                    .foregroundStyle(WatchColor.textPrimary)
                WatchStatusBadge(session.status)
            }
            .watchCard(.hero)
        } else {
            // 빈 상태 문구가 "오늘 세션"을 이미 포함하므로 라벨을 얹지 않는다 — 같은 말이
            // 두 줄로 반복되면 라벨/값 위계가 오히려 흐려진다.
            Text(viewModel.emptySessionMessage)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textSecondary)
                .watchCard()
        }
    }

    private var pingChip: some View {
        Button {
            router.push(.pingList)
        } label: {
            HStack(spacing: WatchLayout.tightSpacing) {
                VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                    Text("The Ping")
                        .font(.watch(.cardLabel))
                        .foregroundStyle(pingAccentColor)
                    Text(viewModel.unreadPingLabel)
                        .font(.watch(.cardValue))
                        .foregroundStyle(WatchColor.textPrimary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.watch(.cardLabel))
                    .foregroundStyle(WatchColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .watchCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var pendingApprovalBadge: some View {
        if let pendingApprovalLabel = viewModel.pendingApprovalLabel {
            // 승인 대기는 앰버(#FFB340)가 아니라 중립 회색 점 + 인디고 링(`.pending`)이다.
            // 앰버는 2026-08-26 개정 이후 지각(`.warning`) 전용이라 여기서 쓰지 않는다.
            WatchStatusBadge(.pending, label: pendingApprovalLabel)
        }
    }

    /// The Ping 강조는 브랜드 액센트다 — 상태 색이 아니라 미확인 여부만 신호한다.
    private var pingAccentColor: Color {
        viewModel.hasUnreadPing ? WatchColor.brandAccent : WatchColor.textSecondary
    }

    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.watch(.cardLabel))
            .foregroundStyle(WatchColor.textSecondary)
    }
}

#if DEBUG
#Preview("HomeGlanceView — 세션 있음") {
    NavigationStack {
        HomeGlanceView(glance: .sample)
    }
    .environment(WatchRouter())
}

#Preview("HomeGlanceView — 세션 없음") {
    NavigationStack {
        HomeGlanceView(glance: .noSession)
    }
    .environment(WatchRouter())
}

#Preview("HomeGlanceView — A11y 크기") {
    NavigationStack {
        HomeGlanceView(glance: .pending)
    }
    .environment(WatchRouter())
    .dynamicTypeSize(.accessibility3)
}
#endif
