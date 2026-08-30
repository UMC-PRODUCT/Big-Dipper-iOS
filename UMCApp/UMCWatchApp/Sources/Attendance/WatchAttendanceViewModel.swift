//
//  WatchAttendanceViewModel.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import ActivityDomain
import Foundation
import HomeDomain

/// 워치 출석 목록의 상태를 관리하는 ViewModel
///
/// 시간대 판정은 직접 계산하지 않고 `ActivityDomain` 의 `AttendanceTimeWindow` 규칙에 위임한다.
/// 일정 데이터 주입 경로(WatchConnectivity)는 #1210·#1207 에서 `apply(schedules:)` 로 연결된다.
@MainActor
@Observable
final class WatchAttendanceViewModel {

    // MARK: - Property

    private(set) var schedules: [ScheduleDetailData] = []

    // MARK: - Function

    /// 출석 필수이면서 본인이 참여자인 일정만 시작 시각 오름차순으로 보관한다.
    ///
    /// iPhone 의 `fetchAvailableSchedules` 와 달리 마감(`.expired`) 일정도 남긴다 —
    /// 워치 목록은 마감 여부를 상태 라벨로 보여준다.
    func apply(schedules: [ScheduleDetailData]) {
        self.schedules = schedules
            .filter { $0.requiresAttendanceApproval && $0.isParticipant }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func timeWindow(
        for schedule: ScheduleDetailData,
        now: Date = Date()
    ) -> AttendanceTimeWindow {
        AttendanceTimeWindow(schedule: schedule, now: now)
    }

    func statusText(for schedule: ScheduleDetailData, now: Date = Date()) -> String {
        switch timeWindow(for: schedule, now: now) {
        case .tooEarly: "출석 전"
        case .onTime: "출석 가능"
        case .lateWindow: "지각 사유"
        case .expired: "마감"
        }
    }
}
