//
//  OperatorAttendancePreviewData.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/6/26.
//

import Foundation

#if DEBUG
/// 운영진 출석 관리 Preview 데이터
struct OperatorAttendancePreviewData {

    // MARK: - OperatorPendingMember Mock

    /// 승인 대기 멤버 목록
    static let pendingMembers: [OperatorPendingMember] = [
        OperatorPendingMember(
            serverID: "member_1",
            participantMemberId: 1,
            name: "이재원",
            nickname: "리버",
            university: "한성대학교",
            requestTime: Date.now.addingTimeInterval(-300),
            reason: "지각 사유입니다. 버스가 늦게 와서 조금 늦었습니다.",
            profileImageURL: "https://picsum.photos/100"
        ),
        OperatorPendingMember(
            serverID: "member_2",
            participantMemberId: 2,
            name: "정의찬",
            nickname: "제옹",
            university: "중앙대학교",
            requestTime: Date.now.addingTimeInterval(-600),
            reason: nil,
            profileImageURL: "https://picsum.photos/101"
        ),
        OperatorPendingMember(
            serverID: "member_3",
            participantMemberId: 3,
            name: "이예지",
            nickname: "소피",
            university: "가천대학교",
            requestTime: Date.now.addingTimeInterval(-900),
            reason: "교통 체증으로 인한 지각",
            profileImageURL: "https://picsum.photos/102"
        ),
        OperatorPendingMember(
            serverID: "member_4",
            participantMemberId: 4,
            name: "김미주",
            nickname: "마티",
            university: "덕성여대",
            requestTime: Date.now.addingTimeInterval(-1200),
            reason: nil,
            profileImageURL: "https://picsum.photos/103"
        )
    ]

    // MARK: - OperatorSessionAttendance Mock

    /// 세션 출석 현황 목록 (ViewModel용)
    static var sessions: [OperatorSessionAttendance] {
        let baseSessions = AttendancePreviewData.sessions

        return [
            // 진행 중 - 승인 대기 있음
            OperatorSessionAttendance(
                serverID: "session_1",
                session: baseSessions[9],  // pm_day - 진행중
                attendanceRate: 0.85,
                attendedCount: 34,
                totalCount: 40,
                pendingCount: pendingMembers.count,
                pendingMembers: pendingMembers
            ),
            // 종료됨 - 모두 승인 완료
            OperatorSessionAttendance(
                serverID: "session_2",
                session: baseSessions[0],  // union_ot - 종료됨
                attendanceRate: 1.0,
                attendedCount: 40,
                totalCount: 40,
                pendingCount: 0
            ),
            // 진행전 - 미래 세션
            OperatorSessionAttendance(
                serverID: "session_3",
                session: baseSessions[10],  // iOS_8 - 30분 후 시작
                attendanceRate: 0.0,
                attendedCount: 0,
                totalCount: 40,
                pendingCount: 0
            )
        ]
    }

    /// ViewModel 초기화용 세션 목록 (API Mock)
    static func createMockSessions() -> [OperatorSessionAttendance] {
        sessions
    }
}
#endif
