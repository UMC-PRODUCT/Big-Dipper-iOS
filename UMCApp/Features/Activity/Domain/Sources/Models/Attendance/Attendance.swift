//
//  Attendance.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 출석 Domain 핵심 엔티티
///
/// GPS 출석과 사유 출석을 모두 표현하며,
/// 불변 값 타입으로 상태 변경 시 `copy` 기반 빌더 메서드를 제공합니다.
public struct Attendance: Identifiable, Equatable {
    public let id: UUID
    public let sessionId: SessionID
    public let userId: UserID
    public let type: AttendanceType
    public let status: AttendanceStatus
    public let locationVerification: LocationVerification?
    public let reason: String?
    public let createdAt: Date

    public init(
        id: UUID = .init(),
        sessionId: SessionID,
        userId: UserID,
        type: AttendanceType,
        status: AttendanceStatus,
        locationVerification: LocationVerification? = nil,
        reason: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.type = type
        self.status = status
        self.locationVerification = locationVerification
        self.reason = reason
        self.createdAt = createdAt
    }

    public func approved(with verification: LocationVerification) -> Self {
        copy(status: .present, locationVerification: verification)
    }

    public func beforeAttendance() -> Self {
        copy(status: .beforeAttendance)
    }

    public func rejected(status: AttendanceStatus) -> Self {
        copy(status: status)
    }

    public func late(reason: String) -> Self {
        copy(status: .late, reason: reason)
    }

    public func absent(reason: String) -> Self {
        copy(status: .absent, reason: reason)
    }

    private func copy(
        type: AttendanceType? = nil,
        status: AttendanceStatus? = nil,
        reason: String? = nil,
        locationVerification: LocationVerification? = nil
    ) -> Self {
        .init(
            sessionId: self.sessionId,
            userId: self.userId,
            type: type ?? self.type,
            status: status ?? self.status,
            locationVerification: locationVerification ?? self.locationVerification,
            reason: reason ?? self.reason
        )
    }
}
