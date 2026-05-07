//
//  AttendanceDecisionResult.swift
//  AppProduct
//

import Foundation

/// 출석 결정 응답 도메인 모델
///
/// V2 출석 액션 엔드포인트(decide / excuse / request)의 공통 응답.
struct AttendanceDecisionResult: Equatable, Sendable {

    // MARK: - Nested Type

    struct DecisionMakerInfo: Equatable, Sendable {
        let memberId: Int
        let name: String
        let nickname: String
        let schoolId: Int
        let schoolName: String
    }

    // MARK: - Property

    /// 결정된 출석 상태 (알 수 없는 값이면 `.unknown`)
    let status: AttendanceStatusV2

    /// 결정 시각 (nil: 아직 미결정)
    let decidedAt: Date?

    /// 결정 사유 (없으면 nil)
    let decisionReason: String?

    /// 사유 결석 내용 (없으면 nil)
    let excuseReason: String?

    /// 체크인 위도 (없으면 nil)
    let latitude: Double?

    /// 체크인 경도 (없으면 nil)
    let longitude: Double?

    /// 결정자 정보 (없으면 nil)
    let decisionMakerMemberInfo: DecisionMakerInfo?

    /// 결정자 존재 여부
    let hasDecisionMakerMember: Bool

    /// 결정 대기 중 여부
    let isPendingDecision: Bool
}

// MARK: - Attendance 호환 변환

extension AttendanceDecisionResult {

    /// V2 결과 → 기존 `Attendance` 도메인으로 어댑팅
    ///
    /// V2 마이그레이션 완료 전까지 `Session.updateState(.loaded(_))` 에서
    /// `Attendance` 를 요구하는 호출처와의 호환을 위해 사용합니다.
    func toAttendance(sessionId: SessionID, userId: UserID) -> Attendance {
        let attendanceStatus: AttendanceStatus = {
            switch status {
            case .present:          return .present
            case .late:             return .late
            case .absent:           return .absent
            case .excused:          return .present
            case .presentPending,
                 .latePending,
                 .excusedPending:   return .pendingApproval
            case .pending, .unknown: return .beforeAttendance
            }
        }()

        let attendanceType: AttendanceType = excuseReason != nil ? .reason : .gps

        return Attendance(
            sessionId: sessionId,
            userId: userId,
            type: attendanceType,
            status: attendanceStatus,
            locationVerification: nil,
            reason: excuseReason ?? decisionReason
        )
    }
}
