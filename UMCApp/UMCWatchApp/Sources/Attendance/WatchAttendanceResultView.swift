//
//  WatchAttendanceResultView.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchDesignSystem
import HomeDomain
import SwiftUI
import UMCFoundation

// MARK: - WatchAttendanceResultView

/// 출석 결과 화면. 출석 확정·지각·공결·결석 네 결과와 그 앞의 승인 대기를 한 화면이 파생한다.
///
/// 풀스크린 배경은 Glass 금지 구역이라 `watchScreenBackground()` + `watchCard(_:)` 로만
/// 표면을 만든다.
struct WatchAttendanceResultView: View {

    // MARK: - Property

    @State private var viewModel: WatchAttendanceResultViewModel

    // MARK: - Init

    init(
        schedule: ScheduleDetailData,
        outcome: Loadable<WatchAttendanceOutcome>,
        cumulativePresentCount: String = "0",
        excuseReason: String? = nil
    ) {
        _viewModel = State(
            initialValue: WatchAttendanceResultViewModel(
                schedule: schedule,
                outcome: outcome,
                cumulativePresentCount: cumulativePresentCount,
                excuseReason: excuseReason
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        .navigationTitle("출석 결과")
        .watchScreenBackground()
    }

    // MARK: - Function

    @ViewBuilder
    private var content: some View {
        switch viewModel.outcome {
        case .idle, .loading:
            VStack(spacing: WatchLayout.tightSpacing) {
                ProgressView()
                Text("결과를 기다리는 중")
                    .font(.watch(.cardValue))
                    .foregroundStyle(WatchColor.textSecondary)
            }
        case .failed(let error):
            Text(error.userMessage)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textPrimary)
                .multilineTextAlignment(.center)
        case .loaded(let outcome):
            resultCard(outcome)
        }
    }

    private func resultCard(_ outcome: WatchAttendanceOutcome) -> some View {
        VStack(alignment: .leading, spacing: WatchLayout.stackSpacing) {
            // 심볼과 제목은 하나의 접근성 요소다 — 심볼을 따로 낭독하면 같은 말이 두 번 나온다.
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                symbol(outcome)
                Text(outcome.title)
                    .font(.watch(.screenTitle))
                    .foregroundStyle(WatchColor.textPrimary)
            }
            .accessibilityElement(children: .combine)

            Text(viewModel.detailText)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textSecondary)

            if outcome == .excused, let excuseReason = viewModel.excuseReason {
                Text(excuseReason)
                    .font(.watch(.caption))
                    .foregroundStyle(WatchColor.textSecondary)
            }

            if let cumulativeText = viewModel.cumulativeText {
                Text(cumulativeText)
                    .font(.watch(.metric))
                    .foregroundStyle(WatchColor.statusSuccess)
            }
        }
        .watchCard(outcome.cardStyle)
    }

    /// `WatchStatusBadge` 를 쓰지 않는다 — 그 컴포넌트는 심볼을 `.cardLabel` 로 고정해서
    /// 결과 화면의 대형 심볼 크기를 낼 수 없다. 팔레트 렌더링 순서(점, 링)는 배지와 동일하다.
    private func symbol(_ outcome: WatchAttendanceOutcome) -> some View {
        Image(systemName: outcome.symbolName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(outcome.symbolTint, outcome.ringTint)
            .font(.watch(.metric))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("WatchAttendanceResultView — 출석 확정") {
    NavigationStack {
        WatchAttendanceResultView(
            schedule: .watchSample(),
            outcome: .loaded(.present),
            cumulativePresentCount: "7"
        )
    }
}

#Preview("WatchAttendanceResultView — 지각 확정") {
    NavigationStack {
        WatchAttendanceResultView(schedule: .watchSample(), outcome: .loaded(.late))
    }
}

#Preview("WatchAttendanceResultView — 공결") {
    NavigationStack {
        WatchAttendanceResultView(
            schedule: .watchSample(),
            outcome: .loaded(.excused),
            excuseReason: "학교 공식 행사 참여"
        )
    }
}

#Preview("WatchAttendanceResultView — 결석") {
    NavigationStack {
        WatchAttendanceResultView(schedule: .watchSample(), outcome: .loaded(.absent))
    }
}

#Preview("WatchAttendanceResultView — 승인 대기") {
    NavigationStack {
        WatchAttendanceResultView(schedule: .watchSample(), outcome: .loaded(.pending))
    }
}

#Preview("WatchAttendanceResultView — A11y 크기") {
    NavigationStack {
        WatchAttendanceResultView(
            schedule: .watchSample(),
            outcome: .loaded(.present),
            cumulativePresentCount: "7"
        )
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
