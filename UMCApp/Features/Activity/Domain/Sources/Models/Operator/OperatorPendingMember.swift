//
//  OperatorPendingMember.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 승인 대기 중인 멤버 정보
///
/// 출석 승인을 기다리고 있는 멤버의 정보를 담습니다.
public struct OperatorPendingMember: Identifiable, Equatable {
    public let id: UUID
    public let serverID: String?
    public let name: String
    public let nickname: String?
    public let university: String
    public let requestTime: Date
    public let reason: String?
    public let profileImageURL: String?

    public init(
        id: UUID = .init(),
        serverID: String? = nil,
        name: String,
        nickname: String? = nil,
        university: String,
        requestTime: Date,
        reason: String? = nil,
        profileImageURL: String? = nil
    ) {
        self.id = id
        self.serverID = serverID
        self.name = name
        self.nickname = nickname
        self.university = university
        self.requestTime = requestTime
        self.reason = reason
        self.profileImageURL = profileImageURL
    }

    /// 사유가 있는지 여부
    public var hasReason: Bool {
        reason != nil && !(reason?.isEmpty ?? true)
    }

    /// 표시용 이름 (닉네임/이름 또는 이름만)
    public var displayName: String {
        if let nickname = nickname {
            return "\(nickname)/\(name)"
        }
        return name
    }
}

// MARK: - Domain → Presentation 변환

extension OperatorPendingMember {
    /// PendingAttendanceRecord(Domain) → OperatorPendingMember(Presentation) 변환
    public init(from record: PendingAttendanceRecord) {
        self.init(
            serverID: String(record.attendanceId),
            name: record.memberName,
            nickname: record.nickname,
            university: record.schoolName,
            requestTime: record.requestedAt,
            reason: record.reason,
            profileImageURL: record.profileImageLink?.absoluteString
        )
    }
}
