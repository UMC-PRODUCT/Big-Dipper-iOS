//
//  Session.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/5/26.
//

import Foundation

/// 세션 엔티티
///
/// 출석 상태를 포함한 세션 정보를 관리합니다.
/// `@Observable`로 출석 상태 변경 시 UI가 자동 업데이트됩니다.
@MainActor
@Observable
final class Session: Identifiable, Equatable {
    let id: SessionID
    let info: SessionInfo

    private(set) var attendanceLoadable: Loadable<Attendance> = .idle
    private(set) var hasSubmitted: Bool = false

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
        && lhs.info.id == rhs.info.id
    }

    var attendance: Attendance? {
        attendanceLoadable.value
    }

    var attendanceStatus: AttendanceStatus {
        // 제출 완료 + 아직 확정되지 않은 경우 → 승인 대기
        if hasSubmitted, attendanceLoadable.value?.status == .beforeAttendance {
            return .pendingApproval
        }
        return attendanceLoadable.value?.status ?? .beforeAttendance
    }

    var isLoading: Bool {
        attendanceLoadable.isLoading
    }

    var isSuccess: Bool {
        hasSubmitted || (attendanceStatus != .beforeAttendance && attendanceStatus != .pendingApproval)
    }

    /// 출석 가능 여부 (출석 전 또는 승인 대기 상태)
    var isAttendanceAvailable: Bool {
        attendanceStatus == .beforeAttendance || attendanceStatus == .pendingApproval
    }

    /// 출석 요청 가능 여부 (도메인 규칙)
    ///
    /// - Parameters:
    ///   - timeWindow: 현재 시간대 (정시/지각/마감 등)
    ///   - isInsideGeofence: 지오펜스 내부 여부
    ///   - isLocationAuthorized: 위치 권한 허용 여부
    /// - Returns: 출석 요청 버튼 활성화 여부
    func canRequestAttendance(
        timeWindow: AttendanceTimeWindow,
        isInsideGeofence: Bool,
        isLocationAuthorized: Bool
    ) -> Bool {
        timeWindow == .onTime
        && isInsideGeofence
        && isLocationAuthorized
        && !isLoading
        && !hasSubmitted
    }

    /// 사유 제출 가능 여부
    ///
    /// 아직 제출하지 않은 세션은 시간대와 무관하게 사유를 제출할 수 있습니다.
    func canSubmitReason() -> Bool {
        !isLoading
        && !hasSubmitted
        && attendanceStatus == .beforeAttendance
    }

    init(info: SessionInfo, initialAttendance: Attendance? = nil) {
        self.info = info
        self.id = info.sessionId
        if let attendance = initialAttendance {
            attendanceLoadable = .loaded(attendance)
        }
    }

    /// 출석 상태 업데이트
    func updateState(_ state: Loadable<Attendance>) {
        self.attendanceLoadable = state
    }

    /// 출석 제출 완료 처리
    func markSubmitted() {
        hasSubmitted = true
    }

    /// 출석 버튼에 표시할 텍스트
    ///
    /// 위치 권한, 지오펜스 상태, 시간대에 따라 적절한 메시지를 반환합니다.
    func buttonTitle(
        isLocationAuthorized: Bool,
        isInsideGeofence: Bool,
        timeWindow: AttendanceTimeWindow
    ) -> String {
        if isLoading {
            return "출석 처리 중..."
        }

        // 승인 대기 상태
        if attendanceStatus == .pendingApproval {
            return "승인 대기 중"
        }

        // 최종 결정됨 (출석 / 지각 / 결석)
        if attendanceStatus != .beforeAttendance && attendanceStatus != .pendingApproval {
            return attendanceStatus.displayText
        }

        // 시간대 체크
        switch timeWindow {
        case .tooEarly:
            return "아직 출석 시간이 아닙니다"
        case .lateWindow:
            return "지각 - 사유를 제출하세요"
        case .expired:
            return "출석 마감됨"
        case .onTime:
            break  // 아래 조건들 계속 체크
        }

        if !isLocationAuthorized {
            return "위치 권한 필요"
        }

        if !isInsideGeofence {
            return "출석 범위 밖"
        }

        return "현 위치로 출석체크"
    }
}
