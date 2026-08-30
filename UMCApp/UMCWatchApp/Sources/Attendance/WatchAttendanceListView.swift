//
//  WatchAttendanceListView.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchDesignSystem
import HomeDomain
import SwiftUI
import UMCFoundation

// MARK: - WatchAttendanceListView

/// 워치 출석 대상 일정 목록. 진행 중인 일정을 선택 표면으로 끌어올리고, 각 행이 출석 플로우
/// 진입점이 된다.
struct WatchAttendanceListView: View {

    // MARK: - Property

    @Environment(WatchAttendanceViewModel.self) private var viewModel
    @Environment(WatchRouter.self) private var router

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle("출석")
            .watchScreenBackground()
    }

    // MARK: - Function

    @ViewBuilder
    private var content: some View {
        switch viewModel.schedules {
        case .idle, .loading:
            ProgressView()
        case .failed(let error):
            failure(error)
        case .loaded(let schedules) where schedules.isEmpty:
            ContentUnavailableView(
                "iPhone 연결 대기",
                systemImage: "iphone.gen3.radiowaves.left.and.right",
                description: Text("iPhone 에서 출석 일정을 받아오는 중입니다.")
            )
        case .loaded(let schedules):
            List(schedules) { schedule in
                row(for: schedule)
            }
        }
    }

    /// 재시도 버튼을 두지 않는다 — 워치는 일정을 직접 조회하지 않고 iPhone 이 밀어주는 쪽이라
    /// 여기서 누를 수 있는 재시도가 존재하지 않는다.
    private func failure(_ error: AppError) -> some View {
        VStack(spacing: WatchLayout.tightSpacing) {
            Text(error.userMessage)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textPrimary)
            Text("iPhone 에서 UMC 앱을 열면 다시 전송됩니다.")
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, WatchLayout.screenHorizontalPadding)
    }

    /// 행 전체가 진입점이다. `.plain` 이어야 행 표면이 solid 로 남는다 —
    /// Glass 버튼 스타일을 쓰면 리스트 행이 Glass 금지 구역을 침범한다.
    private func row(for schedule: ScheduleDetailData) -> some View {
        Button {
            router.push(viewModel.rowRoute(for: schedule))
        } label: {
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                Text(schedule.name)
                    .font(.watch(.cardValue))
                    .foregroundStyle(WatchColor.textPrimary)
                    .lineLimit(2)

                Text(schedule.startsAt, format: .dateTime.month().day().hour().minute())
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.textSecondary)

                WatchStatusBadge(
                    viewModel.status(for: schedule),
                    label: viewModel.statusText(for: schedule)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        // 구분선은 감추지 않는다 — `listRowSeparator` 는 watchOS unavailable 이고,
        // watchOS `List` 는 애초에 행 구분선을 그리지 않아 solid 표면끼리 겹칠 선이 없다.
        .watchListRowBackground(isSelected: viewModel.isInProgress(schedule))
    }
}

#if DEBUG
#Preview("WatchAttendanceListView — 진행 중 포함") {
    NavigationStack {
        WatchAttendanceListView()
    }
    .environment(WatchAttendanceViewModel.watchSample())
    .environment(WatchRouter())
}

#Preview("WatchAttendanceListView — 빈 목록") {
    NavigationStack {
        WatchAttendanceListView()
    }
    .environment(WatchAttendanceViewModel.watchSampleEmpty)
    .environment(WatchRouter())
}

#Preview("WatchAttendanceListView — A11y 크기") {
    NavigationStack {
        WatchAttendanceListView()
    }
    .environment(WatchAttendanceViewModel.watchSample())
    .environment(WatchRouter())
    .dynamicTypeSize(.accessibility3)
}
#endif
