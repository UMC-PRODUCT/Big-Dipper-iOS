//
//  OperatorPendingMember.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/5/26.
//

import Foundation

/// 승인 대기 중인 멤버 정보
///
/// 출석 승인을 기다리고 있는 멤버의 정보를 담습니다.
struct OperatorPendingMember: Identifiable, Equatable {
    let id: UUID = .init()
    let serverID: String?
    /// V2 decideAttendances 에 사용되는 서버 멤버 ID
    let participantMemberId: Int
    let name: String
    let nickname: String?
    let university: String
    let requestTime: Date
    let reason: String?
    let profileImageURL: String?

    /// 사유가 있는지 여부
    var hasReason: Bool {
        reason != nil && !(reason?.isEmpty ?? true)
    }

    /// 표시용 이름 (닉네임/이름 또는 이름만)
    var displayName: String {
        if let nickname = nickname {
            return "\(nickname)/\(name)"
        }
        return name
    }
}

// MARK: - Domain → Presentation 변환

extension OperatorPendingMember {
    /// PendingAttendanceRecord(Domain) → OperatorPendingMember(Presentation) 변환
    init(from record: PendingAttendanceRecord) {
        self.init(
            serverID: String(record.attendanceId),
            participantMemberId: record.memberId,
            name: record.memberName,
            nickname: record.nickname,
            university: record.schoolName,
            requestTime: record.requestedAt,
            reason: record.reason,
            profileImageURL: record.profileImageLink?.absoluteString
        )
    }
}
