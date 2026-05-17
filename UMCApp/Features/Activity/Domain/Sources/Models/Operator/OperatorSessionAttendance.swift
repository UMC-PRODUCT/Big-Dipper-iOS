//
//  OperatorSessionAttendance.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation

/// 운영진 관점의 세션 출석 정보
///
/// 세션별 출석 현황과 승인 대기 멤버 목록을 관리합니다.
///
/// - Note: `session` 프로퍼티의 일부 멤버는 `@MainActor`로 격리되어 있으므로,
///   해당 값에 접근하려면 호출 측이 메인 액터에서 실행되어야 합니다.
public struct OperatorSessionAttendance: Identifiable, Equatable {

    // MARK: - Property

    public let id: UUID
    public let serverID: String?
    public let session: Session
    public let attendanceRate: Double
    public let attendedCount: Int
    public let totalCount: Int
    public let pendingCount: Int
    public let pendingMembers: [OperatorPendingMember]

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        serverID: String? = nil,
        session: Session,
        attendanceRate: Double,
        attendedCount: Int,
        totalCount: Int,
        pendingCount: Int,
        pendingMembers: [OperatorPendingMember] = []
    ) {
        self.id = id
        self.serverID = serverID
        self.session = session
        self.attendanceRate = attendanceRate
        self.attendedCount = attendedCount
        self.totalCount = totalCount
        self.pendingCount = pendingCount
        self.pendingMembers = pendingMembers
    }

    // MARK: - Computed

    /// 모든 출석이 승인 완료되었는지 여부
    public var isAllApproved: Bool {
        pendingCount == 0
    }
}

// MARK: - copyWith

public extension OperatorSessionAttendance {
    /// 특정 프로퍼티만 변경한 새 인스턴스 생성
    ///
    /// - Parameters:
    ///   - attendedCount: 출석 완료 인원 (nil이면 기존 값 유지)
    ///   - pendingCount: 승인 대기 인원 (nil이면 pendingMembers.count 우선, 그 외 기존 값 유지)
    ///   - pendingMembers: 승인 대기 멤버 목록 (nil이면 기존 값 유지)
    /// - Returns: 변경된 프로퍼티가 적용된 새 인스턴스
    ///
    /// - Note: `attendedCount` 변경 시 `attendanceRate`가 자동 재계산됩니다.
    func copyWith(
        attendedCount: Int? = nil,
        pendingCount: Int? = nil,
        pendingMembers: [OperatorPendingMember]? = nil
    ) -> OperatorSessionAttendance {
        let newAttendedCount = attendedCount ?? self.attendedCount
        let newAttendanceRate = totalCount > 0
            ? Double(newAttendedCount) / Double(totalCount)
            : 0.0
        let newPendingMembers = pendingMembers ?? self.pendingMembers
        let newPendingCount = pendingCount
            ?? pendingMembers?.count
            ?? self.pendingCount

        return OperatorSessionAttendance(
            id: self.id,
            serverID: self.serverID,
            session: self.session,
            attendanceRate: newAttendanceRate,
            attendedCount: newAttendedCount,
            totalCount: self.totalCount,
            pendingCount: newPendingCount,
            pendingMembers: newPendingMembers
        )
    }
}
