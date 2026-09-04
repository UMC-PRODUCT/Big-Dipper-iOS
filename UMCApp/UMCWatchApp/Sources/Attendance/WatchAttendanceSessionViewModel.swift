//
//  WatchAttendanceSessionViewModel.swift
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

// MARK: - WatchGeofenceReading

/// 지오펜스 1회 측정 결과.
struct WatchGeofenceReading: Equatable, Sendable {

    /// 출석 장소로부터의 거리(m). 기기 측정값이라 서버 정수 String 규칙(핵심 규칙 #2) 대상이 아니다.
    let distanceMeters: Double

    /// 허용 반경은 앱 전역 상수를 그대로 쓴다 — 워치가 iPhone 과 다른 반경으로 판정하면
    /// 같은 자리에서 기기별로 결과가 갈린다.
    var allowedRadiusMeters: Double { AttendancePolicy.geofenceRadius }

    var isInside: Bool { distanceMeters <= allowedRadiusMeters }

    /// 표시용 반올림 정수 — 대형 지표에 소수점을 띄우지 않는다.
    var displayMeters: Int { Int(distanceMeters.rounded()) }
}

// MARK: - WatchAttendanceSessionViewModel

/// 출석 진행 화면의 표시 로직. 정시·지각·지오펜스 이탈 세 상태를 **데이터에서 파생**한다 —
/// `WatchRoute` 가 케이스를 쪼개지 않는 이유이기도 하다.
@MainActor
@Observable
final class WatchAttendanceSessionViewModel {

    // MARK: - Property

    let schedule: ScheduleDetailData

    /// `.loading` 은 측정 중이다. 실제 CLLocation 측정 연결은 #1210·#1216 이 붙인다.
    private(set) var geofence: Loadable<WatchGeofenceReading> = .idle

    /// 출석 요청을 이미 보냈는지. 전송 자체는 #1210 이 붙인다.
    private(set) var didRequestAttendance = false

    /// 테스트에서 시간창을 고정하기 위한 시계. 프로덕션은 기본값(`Date.init`)을 쓴다.
    private let now: () -> Date

    /// 비대면 일정(`location == nil`)은 측정할 장소가 없다. 지오펜스를 요구하면 CTA 가
    /// 영원히 비활성으로 남으므로 시간창만으로 판정한다.
    private var requiresGeofence: Bool { schedule.location != nil }

    var isOnTime: Bool {
        if case .onTime = timeWindow() { return true }
        return false
    }

    var isLateWindow: Bool {
        if case .lateWindow = timeWindow() { return true }
        return false
    }

    /// 카운트다운이 향하는 마감 시각. 서버 정책이 없으면 `nil` 을 돌려 화면이 타이머를 감춘다 —
    /// 클라이언트 상수로 마감 시각을 지어내면 서버 판정과 다른 숫자를 카운트다운하게 된다.
    var deadline: Date? {
        guard let policy = schedule.attendancePolicy else { return nil }
        switch timeWindow() {
        case .onTime:                       return policy.onTimeEndAt
        case .lateWindow:                   return policy.lateEndAt
        case .tooEarly, .expired:           return nil
        }
    }

    var canCheckIn: Bool {
        guard isOnTime || isLateWindow else { return false }
        guard requiresGeofence else { return true }
        return geofence.value?.isInside == true
    }

    /// CTA 비활성 사유. `WatchActionButton` 계약상 **이게 유일한 비활성 경로**다.
    /// 위치가 먼저인 이유: 시간창 안에 있어도 위치가 확정되기 전엔 누를 수 없고,
    /// 사용자가 당장 할 수 있는 행동(이동·재측정)을 먼저 알려주는 편이 유용하다.
    var disabledReason: String? {
        if requiresGeofence {
            switch geofence {
            case .idle, .loading:
                return "현재 위치를 확인하는 중입니다"
            case .loaded(let reading) where !reading.isInside:
                return "50m 이내로 이동한 뒤 다시 시도해 주세요"
            case .failed:
                return "위치를 확인할 수 없습니다"
            case .loaded:
                break
            }
        }

        switch timeWindow() {
        case .tooEarly:            return "출석 시작 전입니다"
        case .expired:             return "출석 인정 시간이 지났습니다"
        case .onTime, .lateWindow: return nil
        }
    }

    /// 위치 chip 문구. 비대면이면 장소가 없고, 측정 전/실패면 거리 없이 장소만 보여준다 —
    /// 확정되지 않은 거리를 숫자로 띄우면 사용자가 그 값을 믿고 움직인다.
    var locationText: String {
        guard let locationName = schedule.location?.locationName else { return "비대면" }
        switch geofence {
        case .idle, .loading:      return "위치 확인 중"
        case .failed:              return locationName
        case .loaded(let reading): return "\(locationName) · \(reading.displayMeters)m"
        }
    }

    /// 상태 배너 색. 지각 창의 앰버는 **상태색**이고 CTA 인디고는 **액션색**이라 서로 분리된
    /// 축이다 — 지각이어도 CTA 는 인디고 `.primary` 로 둔다.
    var bannerStatus: WatchStatus { timeWindow().watchStatus }

    var bannerText: String {
        switch timeWindow() {
        case .tooEarly:   "출석 시작 전"
        case .onTime:     "정시 출석 창"
        case .lateWindow: "지각 인정 시간"
        case .expired:    "출석 마감"
        }
    }

    /// 지오펜스 이탈 여부 — Crown 재측정과 거리 대형 표시를 붙일지 결정한다.
    var isOutOfRange: Bool {
        guard requiresGeofence, let reading = geofence.value else { return false }
        return !reading.isInside
    }

    // MARK: - Init

    init(schedule: ScheduleDetailData, now: @escaping () -> Date = Date.init) {
        self.schedule = schedule
        self.now = now
    }

    // MARK: - Function

    func timeWindow(now referenceDate: Date? = nil) -> AttendanceTimeWindow {
        AttendanceTimeWindow(schedule: schedule, now: referenceDate ?? now())
    }

    func apply(distanceMeters: Double) {
        geofence = .loaded(WatchGeofenceReading(distanceMeters: distanceMeters))
    }

    func failGeofence(_ error: AppError) {
        geofence = .failed(error)
    }

    /// 측정 중 상태로 되돌린다. 실제 재측정(CLLocation 갱신) 연결은 #1210·#1216 이 붙인다.
    /// 이미 측정 중이면 무시한다 — Crown 은 회전 내내 값을 흘리므로 요청이 쏟아진다.
    func remeasure() {
        guard !geofence.isLoading else { return }
        geofence = .loading
    }

    /// 출석 요청. 전송 자체는 #1210 이 붙인다.
    ///
    /// 요청 직후 화면은 결과가 아니라 **대기**로 간다 — 결과는 `ATTENDANCE_STATUS_CHANGED`
    /// 푸시로만 도착하고 승인까지 수십 분~며칠 걸리기 때문이다(설계 §3.1).
    func requestAttendance() {
        guard canCheckIn else { return }
        didRequestAttendance = true
    }
}
