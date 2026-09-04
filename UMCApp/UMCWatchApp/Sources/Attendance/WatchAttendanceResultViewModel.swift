//
//  WatchAttendanceResultViewModel.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import HomeDomain
import Observation
import UMCFoundation

// MARK: - WatchAttendanceResultViewModel

/// 출석 결과 화면의 표시 로직.
///
/// 결과는 `ATTENDANCE_STATUS_CHANGED` 푸시로만 도착하므로, 아직 안 온 상태(`.loading`)는
/// 실패가 아니라 **승인 대기**다.
@MainActor
@Observable
final class WatchAttendanceResultViewModel {

    // MARK: - Property

    let schedule: ScheduleDetailData

    private(set) var outcome: Loadable<WatchAttendanceOutcome>

    /// 공결 사유 요약. iPhone 이 함께 밀어주면 채워지고, 없으면 감춘다.
    let excuseReason: String?

    /// 누적 출석 횟수. 서버 정수라 전 레이어 String 이다 (핵심 규칙 #2).
    private let cumulativePresentCount: String

    /// 출석 확정일 때만 노출한다 — 지각·공결·결석 화면에 누적 출석을 붙이면 방금 받은 결과가
    /// 출석으로 집계된 것처럼 읽힌다.
    var cumulativeText: String? {
        guard outcome.value == .present else { return nil }
        let count = max(Int(cumulativePresentCount) ?? 0, 0)
        // 값이 비었거나 숫자가 아니면 0 으로 떨어지는데, 그건 "모른다"에 가깝다 —
        // "누적 출석 0회"라고 단정하느니 감춘다.
        guard count > 0 else { return nil }
        return "누적 출석 \(count)회"
    }

    /// 결과가 아직 안 왔으면 대기와 같은 문구다 — 푸시 전 상태가 곧 승인 대기다.
    var detailText: String {
        switch outcome.value ?? .pending {
        case .pending: "운영진 승인을 기다리는 중입니다"
        case .present: "출석이 확정되었습니다"
        case .late:    "정시 출석 창을 넘겨 지각으로 기록되었습니다"
        case .excused: "공결로 인정되었습니다"
        case .absent:  "iPhone 에서 결석 사유를 제출할 수 있습니다"
        }
    }

    // MARK: - Init

    init(
        schedule: ScheduleDetailData,
        outcome: Loadable<WatchAttendanceOutcome>,
        cumulativePresentCount: String = "0",
        excuseReason: String? = nil
    ) {
        self.schedule = schedule
        self.outcome = outcome
        self.cumulativePresentCount = cumulativePresentCount
        self.excuseReason = excuseReason
    }
}
