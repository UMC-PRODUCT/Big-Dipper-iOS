//
//  WatchAttendanceViewModel.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import ActivityDomain
import CoreWatchDesignSystem
import Foundation
import HomeDomain
import Observation
import UMCFoundation

// MARK: - WatchAttendanceViewModel

/// 워치 출석 데이터 스토어 + 목록 표시 로직.
///
/// 앱 셸(`UMCWatchApp`)이 소유하고 `.environment` 로 주입하는 **앱 생명주기 전역 관리자**라
/// `WatchRouter` 와 마찬가지로 절대 규칙 #1 의 예외에 해당한다. 목록·세션·결과 세 화면이
/// 같은 일정 집합과 같은 결과 캐시를 봐야 해서 화면마다 소유하면 상태가 갈라진다.
///
/// 시간대 판정은 직접 계산하지 않고 `ActivityDomain` 의 `AttendanceTimeWindow` 규칙에 위임한다.
@MainActor
@Observable
final class WatchAttendanceViewModel {

    // MARK: - Property

    private(set) var schedules: Loadable<[ScheduleDetailData]> = .idle

    /// scheduleID → `ATTENDANCE_STATUS_CHANGED` 푸시로 받은 결과.
    /// 키가 없으면 "아직 결과가 안 왔다"는 뜻이고, 그건 실패가 아니라 대기다.
    private(set) var outcomes: [String: WatchAttendanceOutcome] = [:]

    // MARK: - Function

    /// 데이터 공급(WatchConnectivity 페이로드 수신)은 #1210 이 붙인다.
    /// 여기서는 전이만 열어 두고 화면이 `.loading` 을 그릴 수 있게 한다.
    func beginLoading() {
        schedules = .loading
    }

    /// 출석 필수이면서 본인이 참여자인 일정만 시작 시각 오름차순으로 보관한다.
    ///
    /// iPhone 의 `fetchAvailableSchedules` 와 달리 마감(`.expired`) 일정도 남긴다 —
    /// 워치 목록은 마감 여부를 상태 라벨로 보여준다.
    func apply(schedules: [ScheduleDetailData]) {
        self.schedules = .loaded(
            schedules
                .filter { $0.requiresAttendanceApproval && $0.isParticipant }
                .sorted { $0.startsAt < $1.startsAt }
        )
    }

    func fail(_ error: AppError) {
        schedules = .failed(error)
    }

    func apply(outcome: WatchAttendanceOutcome, for scheduleID: String) {
        outcomes[scheduleID] = outcome
    }

    func schedule(id: String) -> ScheduleDetailData? {
        schedules.value?.first { $0.scheduleId == id }
    }

    /// 아직 푸시가 안 왔으면 `.loading` 이다 — 승인까지 수십 분~며칠 걸리므로 요청 직후 화면은
    /// 결과가 아니라 대기 상태여야 한다(설계 §3.1).
    func outcome(for scheduleID: String) -> Loadable<WatchAttendanceOutcome> {
        guard let outcome = outcomes[scheduleID] else { return .loading }
        return .loaded(outcome)
    }

    func timeWindow(
        for schedule: ScheduleDetailData,
        now: Date = Date()
    ) -> AttendanceTimeWindow {
        AttendanceTimeWindow(schedule: schedule, now: now)
    }

    func statusText(for schedule: ScheduleDetailData, now: Date = Date()) -> String {
        switch timeWindow(for: schedule, now: now) {
        case .tooEarly:   "출석 전"
        case .onTime:     "출석 가능"
        case .lateWindow: "지각 사유"
        case .expired:    "마감"
        }
    }

    func status(for schedule: ScheduleDetailData, now: Date = Date()) -> WatchStatus {
        timeWindow(for: schedule, now: now).watchStatus
    }

    /// 행 강조 판정. 지금 출석을 진행할 수 있는 창(정시·지각)에 들어와 있는 일정만 강조한다.
    /// 목록에서 `watchListRowBackground(isSelected:)` 인자로 쓴다 — 진행 중은 Hero + 인디고
    /// 색바, 예정/마감은 중립 표면이다.
    func isInProgress(_ schedule: ScheduleDetailData, now: Date = Date()) -> Bool {
        switch timeWindow(for: schedule, now: now) {
        case .onTime, .lateWindow: true
        case .tooEarly, .expired:  false
        }
    }

    /// 행 탭 목적지. 진행 중이면 결과 캐시가 있어도 세션 화면이 우선이다 —
    /// 이전 회차 결과를 보느라 지금 눌러야 할 출석을 놓치면 안 된다.
    func rowRoute(for schedule: ScheduleDetailData, now: Date = Date()) -> WatchRoute {
        let scheduleID = schedule.scheduleId
        if !isInProgress(schedule, now: now), outcomes[scheduleID] != nil {
            return .attendanceResult(scheduleID: scheduleID)
        }
        return .attendanceSession(scheduleID: scheduleID)
    }
}

// MARK: - AttendanceTimeWindow + WatchStatus

extension AttendanceTimeWindow {

    /// 시간창 → 시맨틱 상태 축. 목록 행 배지와 세션 상태 배너가 같은 매핑을 써야 같은 일정이
    /// 두 화면에서 다른 색으로 보이지 않는다.
    ///
    /// 지각 창이 `.warning`(앰버)인 것은 지각 = 앰버 규칙과 같은 축이고, 마감은 출석 자체가
    /// 불가능한 종료 상태라 `.error` 다.
    var watchStatus: WatchStatus {
        switch self {
        case .tooEarly:   .pending
        case .onTime:     .active
        case .lateWindow: .warning
        case .expired:    .error
        }
    }
}

#if DEBUG
extension ScheduleAttendancePolicy {

    /// `reference` 기준 [-10분, +10분, +30분] 창. `AttendancePolicy` 상수와 같은 폭이라
    /// 정책 있는 일정과 없는 일정의 시간대 판정이 프리뷰에서 어긋나지 않는다.
    static func watchSample(around reference: Date) -> ScheduleAttendancePolicy {
        ScheduleAttendancePolicy(
            checkInStartAt: reference.addingTimeInterval(-600),
            onTimeEndAt: reference.addingTimeInterval(600),
            lateEndAt: reference.addingTimeInterval(1_800)
        )
    }
}

extension ScheduleLocation {

    static let watchSample = ScheduleLocation(
        latitude: 37.5665,
        longitude: 126.9780,
        locationName: "공학관 401호"
    )
}

extension ScheduleDetailData {

    /// 프리뷰·테스트 공용 일정 픽스처. 시간창은 `attendancePolicy` 로 직접 잡는다.
    static func watchSample(
        id: String = "1024",
        name: String = "5주차 정기 세션",
        startsAt: Date = .now,
        duration: TimeInterval = 7_200,
        isParticipant: Bool = true,
        location: ScheduleLocation? = .watchSample,
        attendancePolicy: ScheduleAttendancePolicy? = .watchSample(around: .now)
    ) -> ScheduleDetailData {
        ScheduleDetailData(
            scheduleId: id,
            name: name,
            description: "",
            tags: [],
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(duration),
            isParticipant: isParticipant,
            location: location,
            attendancePolicy: attendancePolicy
        )
    }
}

extension WatchAttendanceViewModel {

    /// 진행 중 1건 + 예정 1건 + 마감 1건.
    static func watchSample(now: Date = .now) -> WatchAttendanceViewModel {
        let viewModel = WatchAttendanceViewModel()
        viewModel.apply(schedules: [
            .watchSample(
                id: "1024",
                name: "5주차 정기 세션",
                startsAt: now,
                attendancePolicy: .watchSample(around: now)
            ),
            .watchSample(
                id: "2048",
                name: "6주차 정기 세션",
                startsAt: now.addingTimeInterval(86_400),
                attendancePolicy: .watchSample(around: now.addingTimeInterval(86_400))
            ),
            .watchSample(
                id: "512",
                name: "지난주 스터디",
                startsAt: now.addingTimeInterval(-86_400),
                attendancePolicy: .watchSample(around: now.addingTimeInterval(-86_400))
            ),
        ])
        viewModel.apply(outcome: .present, for: "512")
        return viewModel
    }

    static var watchSampleEmpty: WatchAttendanceViewModel {
        let viewModel = WatchAttendanceViewModel()
        viewModel.apply(schedules: [])
        return viewModel
    }
}
#endif
