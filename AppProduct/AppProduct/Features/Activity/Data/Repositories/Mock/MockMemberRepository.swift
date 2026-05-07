//
//  MockMemberRepository.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import Foundation

/// Preview 및 테스트용 Mock MemberRepository
final class MockMemberRepository: MemberRepositoryProtocol {
    // MARK: - Function
    func fetchMembers() async throws -> [MemberManagementItem] {
        return [
            // 이예지 (Part Leader) - 완벽한 출석
            .init(
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "9기",
                school: "가천대학교",
                position: "Part Leader",
                part: .front(type: .ios),
                penalty: 0,
                badge: false,
                managementTeam: .schoolPartLeader,
                attendanceRecords: MockAttendanceRecords.perfect,
                penaltyHistory: MockPenaltyHistory.none
            ),
            
            // 이예지 (President) - 완벽한 출석
            .init(
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "9기",
                school: "가천대학교",
                position: "Part Leader",
                part: .front(type: .ios),
                penalty: 0,
                badge: false,
                managementTeam: .schoolPartLeader,
                attendanceRecords: MockAttendanceRecords.perfect,
                penaltyHistory: MockPenaltyHistory.oneOut
            ),
            
            // 김철수 - 보통 출석 (몇 번 지각)
            .init(
                profile: nil,
                name: "김철수",
                nickname: "철수",
                generation: "9기",
                school: "한국대학교",
                position: "Member",
                part: .front(type: .android),
                penalty: 1,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: MockAttendanceRecords.average,
                penaltyHistory: MockPenaltyHistory.twoOut
            ),
            
            // 박영희 - 좋은 출석
            .init(
                profile: nil,
                name: "박영희",
                nickname: "영희",
                generation: "9기",
                school: "대한대학교",
                position: "Member",
                part: .server(type: .spring),
                penalty: 0,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: MockAttendanceRecords.good,
                penaltyHistory: MockPenaltyHistory.oneOut
            ),
            
            // 최민수 - 불성실한 출석 (결석 많음)
            .init(
                profile: nil,
                name: "최민수",
                nickname: "민수",
                generation: "9기",
                school: "한국대학교",
                position: "Member",
                part: .front(type: .web),
                penalty: 2,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: MockAttendanceRecords.poor,
                penaltyHistory: MockPenaltyHistory.threeOut
            ),
            
            // 정다은 - 좋은 출석
            .init(
                profile: nil,
                name: "정다은",
                nickname: "다은",
                generation: "9기",
                school: "민국대학교",
                position: "Member",
                part: .design,
                penalty: 0,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: MockAttendanceRecords.good,
                penaltyHistory: MockPenaltyHistory.none
            ),
            
            // 강호진 - 보통 출석
            .init(
                profile: nil,
                name: "강호진",
                nickname: "호진",
                generation: "9기",
                school: "한국대학교",
                position: "Member",
                part: .pm,
                penalty: 5,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: MockAttendanceRecords.average,
                penaltyHistory: MockPenaltyHistory.fiveOut
            ),
            
            // 신입생 - 출석 기록 없음
            .init(
                profile: nil,
                name: "이신입",
                nickname: "신입",
                generation: "9기",
                school: "민국대학교",
                position: "Member",
                part: .front(type: .ios),
                penalty: 0,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: [],
                penaltyHistory: MockPenaltyHistory.oneOut
            ),
        ]
    }

    func grantPoint(
        challengerId: Int,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func deletePoint(
        challengerPointId: Int
    ) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func fetchPointHistory(
        challengerId: Int
    ) async throws -> [OperatorMemberPenaltyHistory] {
        try await Task.sleep(for: .milliseconds(150))
        return MockPenaltyHistory.oneOut
    }

    func fetchAllGenerations(memberId: Int) async throws -> String {
        "8기, 9기"
    }

    func fetchGenerationPointSummaries(
        memberId: Int
    ) async throws -> [GenerationPointSummary] {
        [
            GenerationPointSummary(gisu: 8, reward: 2, penalty: 1),
            GenerationPointSummary(gisu: 9, reward: 1, penalty: 0)
        ]
    }
}

// MARK: - Mock Attendance Records

private enum MockAttendanceRecords {
    /// 완벽한 출석 (7/7 출석)
    static let perfect: [MemberAttendanceRecord] = [
        MemberAttendanceRecord(
            sessionTitle: "OT 및 Git 기초",
            week: 1,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "iOS SwiftUI 기초",
            week: 2,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "네비게이션 & 데이터 플로우",
            week: 3,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "API 통신 & 네트워킹",
            week: 4,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "상태 관리 & MVVM 패턴",
            week: 5,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "클린 아키텍처 & DI",
            week: 6,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "프로젝트 중간 발표",
            week: 7,
            status: .present
        ),
    ]
    
    /// 좋은 출석 (6/7 출석, 1번 지각)
    static let good: [MemberAttendanceRecord] = [
        MemberAttendanceRecord(
            sessionTitle: "OT 및 Git 기초",
            week: 1,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "iOS SwiftUI 기초",
            week: 2,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "네비게이션 & 데이터 플로우",
            week: 3,
            status: .late
        ),
        MemberAttendanceRecord(
            sessionTitle: "API 통신 & 네트워킹",
            week: 4,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "상태 관리 & MVVM 패턴",
            week: 5,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "클린 아키텍처 & DI",
            week: 6,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "프로젝트 중간 발표",
            week: 7,
            status: .present
        ),
    ]
    
    /// 보통 출석 (5/7 출석, 2번 지각)
    static let average: [MemberAttendanceRecord] = [
        MemberAttendanceRecord(
            sessionTitle: "OT 및 Git 기초",
            week: 1,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "iOS SwiftUI 기초",
            week: 2,
            status: .late
        ),
        MemberAttendanceRecord(
            sessionTitle: "네비게이션 & 데이터 플로우",
            week: 3,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "API 통신 & 네트워킹",
            week: 4,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "상태 관리 & MVVM 패턴",
            week: 5,
            status: .late
        ),
        MemberAttendanceRecord(
            sessionTitle: "클린 아키텍처 & DI",
            week: 6,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "프로젝트 중간 발표",
            week: 7,
            status: .present
        ),
    ]
    
    /// 불성실한 출석 (3/7 출석, 2번 지각, 2번 결석)
    static let poor: [MemberAttendanceRecord] = [
        MemberAttendanceRecord(
            sessionTitle: "OT 및 Git 기초",
            week: 1,
            status: .late
        ),
        MemberAttendanceRecord(
            sessionTitle: "iOS SwiftUI 기초",
            week: 2,
            status: .absent
        ),
        MemberAttendanceRecord(
            sessionTitle: "네비게이션 & 데이터 플로우",
            week: 3,
            status: .late
        ),
        MemberAttendanceRecord(
            sessionTitle: "API 통신 & 네트워킹",
            week: 4,
            status: .absent
        ),
        MemberAttendanceRecord(
            sessionTitle: "상태 관리 & MVVM 패턴",
            week: 5,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "클린 아키텍처 & DI",
            week: 6,
            status: .present
        ),
        MemberAttendanceRecord(
            sessionTitle: "프로젝트 중간 발표",
            week: 7,
            status: .present
        ),
    ]
}

// MARK: - Mock Penalty History

private enum MockPenaltyHistory {
    /// 페널티 없음
    static let none: [OperatorMemberPenaltyHistory] = []
    
    /// 1아웃 (지각 1회)
    static let oneOut: [OperatorMemberPenaltyHistory] = [
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 1주 전
            reason: "세션 지각",
            penaltyScore: 1.0
        )
    ]
    
    /// 2아웃 (지각 1회 + 결석 1회)
    static let twoOut: [OperatorMemberPenaltyHistory] = [
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2주 전
            reason: "세션 지각",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 1주 전
            reason: "세션 결석 (사유 없음)",
            penaltyScore: 1.0
        )
    ]
    
    /// 3아웃 이상 (지각 + 결석 + 과제 미제출)
    static let threeOut: [OperatorMemberPenaltyHistory] = [
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-21 * 24 * 60 * 60), // 3주 전
            reason: "세션 지각 (교통 체증)",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2주 전
            reason: "워크북 미제출",
            penaltyScore: 0.5
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 1주 전
            reason: "세션 결석 (사유 없음)",
            penaltyScore: 1.0
        )
    ]

    /// 5아웃 (히스토리 길이 확인용)
    static let fiveOut: [OperatorMemberPenaltyHistory] = [
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-35 * 24 * 60 * 60), // 5주 전
            reason: "세션 지각",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-28 * 24 * 60 * 60), // 4주 전
            reason: "워크북 미제출",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-21 * 24 * 60 * 60), // 3주 전
            reason: "세션 결석 (사전 공유 없음)",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-14 * 24 * 60 * 60), // 2주 전
            reason: "세션 지각",
            penaltyScore: 1.0
        ),
        OperatorMemberPenaltyHistory(
            date: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 1주 전
            reason: "세션 지각",
            penaltyScore: 1.0
        )
    ]
}
