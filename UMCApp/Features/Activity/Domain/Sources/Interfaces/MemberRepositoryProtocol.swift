//
//  MemberRepositoryProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation
import UMCFoundation

/// 운영진 멤버 관리 데이터 접근 Repository
///
/// 멤버 목록 조회(전체/페이지), 챌린저 상벌점 부여·삭제·이력 조회,
/// 멤버 출석 이력 및 기수별 상벌점 요약 조회를 담당합니다.
///
/// 모든 서버 식별자는 `String` 으로 통일합니다.
public protocol MemberRepositoryProtocol {

    // MARK: - 멤버 목록

    /// 멤버 목록 전체 조회
    func fetchMembers() async throws -> [MemberManagementItem]

    /// 멤버 목록 페이지 단위 조회 (offset 기반)
    ///
    /// - Parameter page: 0-based 페이지 인덱스
    func fetchMembersPage(page: Int) async throws -> MemberPage

    // MARK: - 상벌점 부여 / 삭제

    /// 챌린저에게 포인트를 부여합니다.
    ///
    /// - Parameters:
    ///   - challengerId: 대상 챌린저 식별자 (서버 응답)
    ///   - pointType: 포인트 유형
    ///   - pointValue: 배점 (`ChallengerPointType/isCustom` 인 경우 직접 입력)
    ///   - description: 부여 사유
    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws

    /// 챌린저 포인트를 삭제합니다.
    ///
    /// - Parameter challengerPointId: 삭제할 포인트 식별자 (서버 응답)
    func deletePoint(challengerPointId: String) async throws

    /// 특정 챌린저의 포인트 히스토리를 조회합니다.
    ///
    /// - Parameter challengerId: 조회 대상 챌린저 식별자 (서버 응답)
    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory]

    // MARK: - 멤버 상세

    /// 멤버 프로필에서 모든 활동 기수 텍스트를 조회합니다.
    ///
    /// - Parameter memberId: 조회 대상 멤버 식별자 (서버 응답)
    func fetchAllGenerations(memberId: String) async throws -> String

    /// 멤버의 기수별 상벌점 요약을 조회합니다.
    ///
    /// - Parameter memberId: 조회 대상 멤버 식별자 (서버 응답)
    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary]

    /// 일정 출석 현황에서 특정 멤버의 출석 이력을 조회합니다.
    ///
    /// - Parameter memberId: 조회 대상 멤버 식별자 (서버 응답)
    /// - Returns: 해당 멤버가 포함된 일정별 출석 기록. 결과 없으면 빈 배열 반환.
    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord]
}
