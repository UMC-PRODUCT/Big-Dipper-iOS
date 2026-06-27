//
//  FetchMembersUseCase.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation
import UMCFoundation

/// `FetchMembersUseCaseProtocol` 의 기본 구현체
///
/// 모든 호출을 `MemberRepositoryProtocol` 에 위임하는 얇은 facade 입니다. 서버 식별자는
/// 전 레이어 `String` 으로 통일되어 그대로 전달됩니다.
public final class FetchMembersUseCase: FetchMembersUseCaseProtocol {

    // MARK: - Property

    private let repository: MemberRepositoryProtocol

    // MARK: - Init

    public init(repository: MemberRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute() async throws -> [MemberManagementItem] {
        try await repository.fetchMembers()
    }

    public func executePage(page: Int) async throws -> MemberPage {
        try await repository.fetchMembersPage(page: page)
    }

    public func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        try await repository.grantPoint(
            challengerId: challengerId,
            pointType: pointType,
            pointValue: pointValue,
            description: description
        )
    }

    public func deletePoint(challengerPointId: String) async throws {
        try await repository.deletePoint(challengerPointId: challengerPointId)
    }

    public func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        try await repository.fetchPointHistory(challengerId: challengerId)
    }

    public func fetchAllGenerations(memberId: String) async throws -> String {
        try await repository.fetchAllGenerations(memberId: memberId)
    }

    public func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        try await repository.fetchGenerationPointSummaries(memberId: memberId)
    }

    public func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        try await repository.fetchAttendanceRecords(memberId: memberId)
    }
}
