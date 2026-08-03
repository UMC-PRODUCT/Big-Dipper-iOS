//
//  MemberListPreviewSupport.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import CoreDomain
import Foundation
import UMCFoundation

// MARK: - Preview Stub UseCase

/// 네트워크 없이 구성원 목록·상세 시트를 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
///
/// 상벌점 부여·삭제는 서버 왕복 대신 로컬 히스토리에 반영해, 화면이 갱신 결과를 다시
/// 조회하는 경로(`fetchPointHistory`)까지 그대로 태운다.
final class PreviewMemberListUseCase: FetchMembersUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let lock = NSLock()
    private var members: [MemberManagementItem]
    private var historyByChallenger: [String: [OperatorMemberPenaltyHistory]]

    // MARK: - Init

    init(members: [MemberManagementItem] = MemberListPreviewData.members) {
        self.members = members
        self.historyByChallenger = Dictionary(
            uniqueKeysWithValues: members.compactMap { member in
                member.challengerID.map { ($0, member.penaltyHistory) }
            }
        )
    }

    // MARK: - Function

    func execute() async throws -> [MemberManagementItem] {
        lock.lock()
        defer { lock.unlock() }
        return members
    }

    func executePage(page: Int) async throws -> MemberPage {
        lock.lock()
        defer { lock.unlock() }
        // 프리뷰 픽스처는 1페이지 분량만 제공하므로 이후 페이지는 빈 결과로 종료한다.
        guard page == 0 else {
            return MemberPage(members: [], hasNext: false, currentPage: page)
        }
        return MemberPage(members: members, hasNext: false, currentPage: page)
    }

    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        lock.lock()
        defer { lock.unlock() }
        let record = OperatorMemberPenaltyHistory(
            challengerPointId: "preview-\(historyByChallenger[challengerId]?.count ?? 0)",
            date: MemberListPreviewData.referenceDate,
            reason: description,
            penaltyScore: Double(pointValue),
            pointType: pointType
        )
        historyByChallenger[challengerId, default: []].insert(record, at: 0)
    }

    func deletePoint(challengerPointId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        for (challengerId, records) in historyByChallenger {
            historyByChallenger[challengerId] = records.filter {
                $0.challengerPointId != challengerPointId
            }
        }
    }

    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        lock.lock()
        defer { lock.unlock() }
        return historyByChallenger[challengerId] ?? []
    }

    func fetchAllGenerations(memberId: String) async throws -> String {
        MemberListPreviewData.generations
    }

    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        MemberListPreviewData.generationPointSummaries
    }

    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        MemberListPreviewData.attendanceRecords
    }
}

// MARK: - Preview Data

/// 구성원 목록 화면 프리뷰 픽스처
enum MemberListPreviewData {

    /// 픽스처 기준 시각 (2026-08-03 19:00 KST)
    static let referenceDate = Date(timeIntervalSince1970: 1_785_492_000)

    static let generations = "11, 12"

    static let generationPointSummaries: [GenerationPointSummary] = [
        GenerationPointSummary(gisu: 12, reward: 5, penalty: 6),
        GenerationPointSummary(gisu: 11, reward: 4, penalty: 0),
    ]

    static let attendanceRecords: [MemberAttendanceRecord] = [
        MemberAttendanceRecord(sessionTitle: "1주차 OT", week: 1, status: .present),
        MemberAttendanceRecord(sessionTitle: "2주차 세미나", week: 2, status: .late),
        MemberAttendanceRecord(sessionTitle: "3주차 스터디", week: 3, status: .absent),
        MemberAttendanceRecord(sessionTitle: "4주차 데모데이", week: 4, status: .beforeAttendance),
    ]

    static let members: [MemberManagementItem] = [
        makeMember(
            id: "11",
            name: "김챌린",
            nickname: "챌린",
            part: .front(type: .ios),
            position: "챌린저",
            team: .challenger,
            penalty: 6,
            reward: 5
        ),
        makeMember(
            id: "12",
            name: "박안드",
            nickname: "안드",
            part: .front(type: .android),
            position: "챌린저",
            team: .challenger,
            penalty: 0,
            reward: 3
        ),
        makeMember(
            id: "13",
            name: "이서버",
            nickname: "서버",
            part: .server(type: .spring),
            position: "파트장",
            team: .schoolPartLeader,
            penalty: 2,
            reward: 8
        ),
        makeMember(
            id: "14",
            name: "최기획",
            nickname: "기획",
            part: .pm,
            position: "회장",
            team: .schoolPresident,
            penalty: 0,
            reward: 12,
            badge: true
        ),
        makeMember(
            id: "15",
            name: "정디자",
            nickname: "디자",
            part: .design,
            position: "챌린저",
            team: .challenger,
            penalty: 4,
            reward: 1
        ),
    ]

    // MARK: - Helper

    private static func makeMember(
        id: String,
        name: String,
        nickname: String,
        part: UMCPartType,
        position: String,
        team: ManagementTeam,
        penalty: Double,
        reward: Double,
        badge: Bool = false
    ) -> MemberManagementItem {
        MemberManagementItem(
            memberID: id,
            challengerID: "1\(id)",
            profile: nil,
            name: name,
            nickname: nickname,
            generation: "12",
            school: "한성대학교",
            position: position,
            part: part,
            penalty: penalty,
            rewardPoints: reward,
            badge: badge,
            managementTeam: team,
            attendanceRecords: attendanceRecords,
            penaltyHistory: penalty > 0 ? penaltyHistory : [],
            generationPoints: generationPointSummaries
        )
    }

    private static let penaltyHistory: [OperatorMemberPenaltyHistory] = [
        OperatorMemberPenaltyHistory(
            challengerPointId: "9001",
            date: referenceDate.addingTimeInterval(-604_800),
            reason: "스터디 지각",
            penaltyScore: 2,
            pointType: .studyLate
        ),
        OperatorMemberPenaltyHistory(
            challengerPointId: "9002",
            date: referenceDate.addingTimeInterval(-1_209_600),
            reason: "워크북 미제출",
            penaltyScore: 4,
            pointType: .noWorkbookMission
        ),
    ]
}

// MARK: - Preview ViewModel

/// 프리뷰용 `MemberListViewModel` 을 조립한다.
///
/// - Parameter session: 화면이 참조하는 권한 세션. 운영진 화면은 상벌점 부여 권한이 열린
///   세션을, 챌린저 화면은 기본 세션을 넘긴다.
@MainActor
func previewMemberListViewModel(
    errorHandler: ErrorHandler,
    session: UserSessionManager
) -> MemberListViewModel {
    MemberListViewModel(
        fetchMembersUseCase: PreviewMemberListUseCase(),
        errorHandler: errorHandler,
        userSessionManager: session
    )
}
#endif
