//
//  WatchAttendanceSessionView.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchDesignSystem
import HomeDomain
import SwiftUI

// MARK: - WatchAttendanceSessionView

/// 출석 진행 화면. 정시·지각·지오펜스 이탈은 별도 화면이 아니라 이 화면이 데이터에서 파생하는
/// 세 가지 시각 상태다.
struct WatchAttendanceSessionView: View {

    // MARK: - Property

    @State private var viewModel: WatchAttendanceSessionViewModel

    /// Crown 회전 누적값. 값 자체는 쓰지 않고 변화만 재측정 트리거로 쓴다.
    @State private var crownPosition: Double = 0

    // MARK: - Init

    /// - Parameter geofenceDistanceMeters: 초기 측정값 주입 지점. 실제 측정 파이프라인이
    ///   붙기 전(#1210·#1216)까지 프리뷰가 이탈 상태를 만들 수 있는 유일한 경로다.
    init(schedule: ScheduleDetailData, geofenceDistanceMeters: Double? = nil) {
        let viewModel = WatchAttendanceSessionViewModel(schedule: schedule)
        if let geofenceDistanceMeters {
            viewModel.apply(distanceMeters: geofenceDistanceMeters)
        }
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchLayout.stackSpacing) {
                banner
                countdown
                locationChip
                outOfRangeCard
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
        // 이탈 상태에서만 포커스를 받는다 — 그 외에는 Crown 이 기본 스크롤로 남아야 한다.
        .focusable(viewModel.isOutOfRange)
        .digitalCrownRotation($crownPosition)
        .onChange(of: crownPosition) { _, _ in
            guard viewModel.isOutOfRange else { return }
            viewModel.remeasure()
        }
        .navigationTitle(viewModel.schedule.name)
        .watchScreenBackground()
        .safeAreaInset(edge: .bottom) {
            // 지각이어도 role 은 `.primary`(인디고)다. 상태색(앰버)과 액션색(인디고)은
            // 분리된 축이라 상태가 액션 버튼의 색을 바꾸지 않는다.
            WatchActionButton(
                "출석 요청",
                role: .primary,
                systemImage: "checkmark",
                disabledReason: viewModel.disabledReason
            ) {
                viewModel.requestAttendance()
            }
            .padding(.horizontal, WatchLayout.screenHorizontalPadding)
        }
    }

    // MARK: - Function

    private var banner: some View {
        WatchStatusBadge(viewModel.bannerStatus, label: viewModel.bannerText)
            .watchCard()
    }

    /// 마감이 없거나(정책 미부착) 이미 지난 시각이면 카운트다운을 감춘다 —
    /// 0 에 멈춘 타이머는 아직 시간이 남아 있다는 오해를 준다.
    @ViewBuilder
    private var countdown: some View {
        if let deadline = viewModel.deadline, deadline > Date.now {
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                Text("남은 시간")
                    .font(.watch(.cardLabel))
                    .foregroundStyle(WatchColor.textSecondary)

                Text(timerInterval: Date.now...deadline, countsDown: true)
                    .font(.watch(.metric))
                    .foregroundStyle(countdownColor)
            }
            .watchCard(.hero)
        }
    }

    private var countdownColor: Color {
        viewModel.isLateWindow ? WatchColor.statusWarning : WatchColor.textPrimary
    }

    private var locationChip: some View {
        HStack(spacing: WatchLayout.tightSpacing) {
            Image(systemName: "location.fill")
                .font(.watch(.cardLabel))
                .foregroundStyle(WatchColor.brandPrimaryHighlight)
                .accessibilityHidden(true)

            Text(viewModel.locationText)
                .font(.watch(.cardValue))
                .foregroundStyle(WatchColor.textPrimary)
                .lineLimit(2)
        }
        .watchCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var outOfRangeCard: some View {
        if viewModel.isOutOfRange, let reading = viewModel.geofence.value {
            VStack(alignment: .leading, spacing: WatchLayout.tightSpacing) {
                Text("출석 장소에서")
                    .font(.watch(.cardLabel))
                    .foregroundStyle(WatchColor.textSecondary)

                Text("\(reading.displayMeters)m")
                    .font(.watch(.metric))
                    .foregroundStyle(WatchColor.statusWarning)
            }
            .watchCard(.danger)
            .accessibilityElement(children: .combine)

            Text("Digital Crown 을 돌려 거리를 다시 측정합니다")
                .font(.watch(.caption))
                .foregroundStyle(WatchColor.textSecondary)
        }
    }
}

#if DEBUG
private extension ScheduleDetailData {

    /// 지금이 정시 창 안인 일정.
    static var watchOnTimeSample: ScheduleDetailData {
        .watchSample(startsAt: .now, attendancePolicy: .watchSample(around: .now))
    }

    /// 정시 창을 넘겨 지각 창에 들어온 일정 (시작 15분 경과).
    static var watchLateSample: ScheduleDetailData {
        let startsAt = Date.now.addingTimeInterval(-900)
        return .watchSample(startsAt: startsAt, attendancePolicy: .watchSample(around: startsAt))
    }
}

#Preview("WatchAttendanceSessionView — 정시") {
    NavigationStack {
        WatchAttendanceSessionView(
            schedule: .watchOnTimeSample,
            geofenceDistanceMeters: 12
        )
    }
}

#Preview("WatchAttendanceSessionView — 지각") {
    NavigationStack {
        WatchAttendanceSessionView(
            schedule: .watchLateSample,
            geofenceDistanceMeters: 12
        )
    }
}

#Preview("WatchAttendanceSessionView — 지오펜스 이탈") {
    NavigationStack {
        WatchAttendanceSessionView(
            schedule: .watchOnTimeSample,
            geofenceDistanceMeters: 72
        )
    }
}

#Preview("WatchAttendanceSessionView — A11y 크기") {
    NavigationStack {
        WatchAttendanceSessionView(
            schedule: .watchOnTimeSample,
            geofenceDistanceMeters: 72
        )
    }
    .dynamicTypeSize(.accessibility3)
}
#endif
