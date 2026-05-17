//
//  FetchMembersUseCaseProtocol.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import Foundation

/// 멤버 목록 조회 UseCase
protocol FetchMembersUseCaseProtocol {
    /// 멤버 목록 조회
    func execute() async throws -> [MemberManagementItem]

    /// 멤버 목록 페이지 단위 조회
    func executePage(page: Int) async throws -> MemberPage

    /// 챌린저에게 포인트를 부여합니다.
    func grantPoint(
        challengerId: Int,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws

    /// 챌린저 포인트를 삭제합니다.
    func deletePoint(
        challengerPointId: Int
    ) async throws

    /// 특정 챌린저의 포인트 히스토리를 조회합니다.
    func fetchPointHistory(
        challengerId: Int
    ) async throws -> [OperatorMemberPenaltyHistory]

    /// 멤버 프로필에서 모든 활동 기수 텍스트를 조회합니다.
    func fetchAllGenerations(memberId: Int) async throws -> String

    /// 멤버의 기수별 상벌점 요약을 조회합니다.
    func fetchGenerationPointSummaries(
        memberId: Int
    ) async throws -> [GenerationPointSummary]

    /// V2 일정 출석 현황에서 특정 멤버의 출석 이력을 조회합니다.
    func fetchAttendanceRecords(memberId: Int) async throws -> [MemberAttendanceRecord]
}
