//
//  AttendanceDecisionResult.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 출석 결정 결과
///
/// 여러 출석 결정 액션(승인/사유/요청)의 공통 응답을 단일 모델로 표현합니다.
public struct AttendanceDecisionResult: Equatable, Sendable {

    // MARK: - Nested Type

    public struct DecisionMakerInfo: Equatable, Sendable {
        public let memberId: String
        public let name: String
        public let nickname: String
        public let schoolId: String
        public let schoolName: String

        public init(
            memberId: String,
            name: String,
            nickname: String,
            schoolId: String,
            schoolName: String
        ) {
            self.memberId = memberId
            self.name = name
            self.nickname = nickname
            self.schoolId = schoolId
            self.schoolName = schoolName
        }
    }

    // MARK: - Property

    /// 결정된 출석 상태 (알 수 없는 값이면 `.unknown`)
    public let status: ParticipantAttendanceStatus

    /// 결정 시각 (nil: 아직 미결정)
    public let decidedAt: Date?

    /// 결정 사유
    public let decisionReason: String?

    /// 사유 결석 내용
    public let excuseReason: String?

    public let latitude: Double?

    public let longitude: Double?

    /// 승인자 정보
    public let decisionMakerMemberInfo: DecisionMakerInfo?

    /// 승인 대기 중 여부
    public let isPendingDecision: Bool

    /// 승인자 존재 여부 (`decisionMakerMemberInfo` 와 1:1 연동)
    ///
    /// 별도 필드로 분리하면 `info = nil && hasDecisionMakerMember = true` 같은
    /// 불일치 상태가 생성자에서 허용되므로, 단일 정보원에서 파생합니다.
    public var hasDecisionMakerMember: Bool { decisionMakerMemberInfo != nil }

    public init(
        status: ParticipantAttendanceStatus,
        decidedAt: Date?,
        decisionReason: String?,
        excuseReason: String?,
        latitude: Double?,
        longitude: Double?,
        decisionMakerMemberInfo: DecisionMakerInfo?,
        isPendingDecision: Bool
    ) {
        self.status = status
        self.decidedAt = decidedAt
        self.decisionReason = decisionReason
        self.excuseReason = excuseReason
        self.latitude = latitude
        self.longitude = longitude
        self.decisionMakerMemberInfo = decisionMakerMemberInfo
        self.isPendingDecision = isPendingDecision
    }
}

// MARK: - Attendance 호환 변환

extension AttendanceDecisionResult {

    /// 승인 결과를 기존 ``Attendance`` 로 어댑팅 (호환 어댑터)
    ///
    /// 도메인 규칙:
    /// - `.excused` 는 ``Attendance`` 에서 출석으로 인정 (`.present` 로 합침)
    /// - `*_PENDING` 계열은 모두 `.pendingApproval` 로 합침
    /// - `excuseReason` 의 존재가 출석 유형(`.reason` vs `.gps`)을 결정
    /// - `reason` 은 사용자가 적은 `excuseReason` 을 운영진의 `decisionReason` 보다 우선
    public func toAttendance(sessionId: SessionID, userId: UserID) -> Attendance {
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
