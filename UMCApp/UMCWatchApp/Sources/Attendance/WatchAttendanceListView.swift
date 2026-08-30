//
//  WatchAttendanceListView.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import HomeDomain
import SwiftUI

/// 워치 출석 대상 일정 목록
///
/// 디자인 토큰(`CoreDesignSystem`)은 iOS 전용이라 링크할 수 없어 SwiftUI 기본 스타일만 쓴다.
/// 워치 전용 토큰은 #1205 에서 정리한다.
struct WatchAttendanceListView: View {

    // MARK: - Property

    @State private var viewModel: WatchAttendanceViewModel

    // MARK: - Init

    /// - Parameter viewModel: 프리뷰/테스트용 주입 지점 (기본값: 빈 목록으로 시작)
    init(viewModel: WatchAttendanceViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? WatchAttendanceViewModel())
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.schedules.isEmpty {
                ContentUnavailableView(
                    "iPhone 연결 대기",
                    systemImage: "iphone.gen3.radiowaves.left.and.right",
                    description: Text("iPhone 에서 출석 일정을 받아오는 중입니다.")
                )
            } else {
                List(viewModel.schedules) { schedule in
                    row(for: schedule)
                }
            }
        }
        .navigationTitle("출석")
    }

    // MARK: - Function

    private func row(for schedule: ScheduleDetailData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schedule.name)
                .font(.headline)
                .lineLimit(2)

            Text(schedule.startsAt, format: .dateTime.month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(viewModel.statusText(for: schedule))
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let now = Date()
    let viewModel = WatchAttendanceViewModel()
    viewModel.apply(schedules: [
        ScheduleDetailData(
            scheduleId: "1",
            name: "1주차 정기 세션",
            description: "",
            tags: [],
            startsAt: now,
            endsAt: now.addingTimeInterval(7_200),
            isParticipant: true,
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: now.addingTimeInterval(-600),
                onTimeEndAt: now.addingTimeInterval(600),
                lateEndAt: now.addingTimeInterval(1_800)
            )
        ),
        ScheduleDetailData(
            scheduleId: "2",
            name: "지난주 스터디",
            description: "",
            tags: [],
            startsAt: now.addingTimeInterval(-86_400),
            endsAt: now.addingTimeInterval(-79_200),
            isParticipant: true,
            attendancePolicy: ScheduleAttendancePolicy(
                checkInStartAt: now.addingTimeInterval(-87_000),
                onTimeEndAt: now.addingTimeInterval(-85_800),
                lateEndAt: now.addingTimeInterval(-84_600)
            )
        ),
    ])

    return NavigationStack {
        WatchAttendanceListView(viewModel: viewModel)
    }
}
#endif
