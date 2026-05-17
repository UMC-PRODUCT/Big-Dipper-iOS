//
//  FetchMembersUseCase.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import Foundation

/// 멤버 목록 조회 UseCase 구현체
final class FetchMembersUseCase: FetchMembersUseCaseProtocol {
    // MARK: - Property
    private let repository: MemberRepositoryProtocol

    // MARK: - Init
    init(repository: MemberRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function
    func execute() async throws -> [MemberManagementItem] {
        try await repository.fetchMembers()
    }

    func executePage(page: Int) async throws -> MemberPage {
        try await repository.fetchMembersPage(page: page)
    }

    func grantPoint(
        challengerId: Int,
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

    func deletePoint(
        challengerPointId: Int
    ) async throws {
        try await repository.deletePoint(
            challengerPointId: challengerPointId
        )
    }

    func fetchPointHistory(
        challengerId: Int
    ) async throws -> [OperatorMemberPenaltyHistory] {
        try await repository.fetchPointHistory(
            challengerId: challengerId
        )
    }

    func fetchAllGenerations(memberId: Int) async throws -> String {
        try await repository.fetchAllGenerations(memberId: memberId)
    }

    func fetchGenerationPointSummaries(
        memberId: Int
    ) async throws -> [GenerationPointSummary] {
        try await repository.fetchGenerationPointSummaries(memberId: memberId)
    }

    func fetchAttendanceRecords(memberId: Int) async throws -> [MemberAttendanceRecord] {
        try await repository.fetchAttendanceRecords(memberId: memberId)
    }
}
