//
//  MemberListViewModel.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import SwiftUI

/// 멤버 목록 화면의 상태를 관리하는 ViewModel
@Observable
final class MemberListViewModel {
    // MARK: - Dependency

    private let fetchMembersUseCase: FetchMembersUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let userSessionManager: UserSessionManager

    // MARK: - Properties

    var searchText: String = ""
    var selectedMember: MemberManagementItem?
    private(set) var membersState: Loadable<[MemberManagementItem]> = .idle
    var alertPrompt: AlertPrompt?
    private(set) var isSubmittingPoint: Bool = false
    private(set) var isDeletingPoint: Bool = false
    private(set) var isLoadingMemberDetail: Bool = false

    // MARK: - Init

    init(
        fetchMembersUseCase: FetchMembersUseCaseProtocol,
        errorHandler: ErrorHandler,
        userSessionManager: UserSessionManager
    ) {
        self.fetchMembersUseCase = fetchMembersUseCase
        self.errorHandler = errorHandler
        self.userSessionManager = userSessionManager
    }

    // MARK: - Computed Properties

    /// 현재 사용자 역할 기반 사용 가능한 포인트 타입
    var availablePointTypes: [ChallengerPointType] {
        ChallengerPointType.availableTypes(for: userSessionManager.currentRole.level)
    }

    /// 검색어로 필터링된 멤버 목록
    private var filteredMembers: [MemberManagementItem] {
        guard case .loaded(let items) = membersState else {
            return []
        }

        if searchText.isEmpty {
            return items
        }

        return items.filter { member in
            member.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Part별로 그룹핑된 멤버 목록
    var groupedMembers: [(part: UMCPartType, members: [MemberManagementItem])] {
        let grouped = Dictionary(grouping: filteredMembers, by: { $0.part })
        return grouped
            .map { (part: $0.key, members: $0.value) }
            .sorted { $0.part.sortOrder < $1.part.sortOrder }
    }

    /// 검색 결과가 비어있는지 여부
    var isSearchResultEmpty: Bool {
        !searchText.isEmpty && filteredMembers.isEmpty
    }

    // MARK: - Action

    /// 멤버 전체 목록을 조회합니다.
    @MainActor
    func fetchMembers() async {
        membersState = .loading
        do {
            let members = try await fetchMembersUseCase.execute()
            membersState = .loaded(members)
        } catch let error as AppError {
            membersState = .failed(error)
        } catch let error as DomainError {
            membersState = .failed(.domain(error))
        } catch let error as NetworkError {
            membersState = .failed(.network(error))
        } catch let error as RepositoryError {
            membersState = .failed(.repository(error))
        } catch {
            membersState = .failed(
                .unknown(message: error.localizedDescription)
            )
        }
    }

    /// 멤버에게 포인트를 부여합니다.
    @MainActor
    func submitPoint(
        member: MemberManagementItem,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async -> Bool {
        let trimmedDescription = description.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedDescription.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "포인트 부여 실패",
                message: "사유를 입력해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        guard let challengerId = member.challengerID else {
            alertPrompt = AlertPrompt(
                title: "포인트 부여 실패",
                message: "챌린저 ID를 찾을 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        isSubmittingPoint = true
        defer { isSubmittingPoint = false }

        do {
            try await fetchMembersUseCase.grantPoint(
                challengerId: challengerId,
                pointType: pointType,
                pointValue: pointValue,
                description: trimmedDescription
            )

            try await reloadMembersAndReselect(member: member)
            NotificationCenter.default.post(name: .memberPenaltyUpdated, object: nil)
            return true
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "포인트 부여 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
            return false
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Activity",
                    action: "submitPoint"
                )
            )
            return false
        }
    }

    /// 챌린저 멤버 상세 시트를 표시합니다.
    @MainActor
    func openChallengerMemberDetail(
        _ member: MemberManagementItem
    ) async {
        guard member.challengerID != nil else {
            selectedMember = member
            return
        }

        isLoadingMemberDetail = true
        defer { isLoadingMemberDetail = false }

        let memberId = member.memberID ?? 0
        async let generationsTask = try? fetchMembersUseCase.fetchAllGenerations(
            memberId: memberId
        )

        var detailedMember = await fetchMemberDetail(for: member)

        let generations = await generationsTask ?? member.generation
        if !generations.isEmpty {
            detailedMember = MemberManagementItem(
                id: detailedMember.id,
                memberID: detailedMember.memberID,
                challengerID: detailedMember.challengerID,
                profile: detailedMember.profile,
                name: detailedMember.name,
                nickname: detailedMember.nickname,
                generation: generations,
                school: detailedMember.school,
                position: detailedMember.position,
                part: detailedMember.part,
                penalty: detailedMember.penalty,
                rewardPoints: detailedMember.rewardPoints,
                badge: detailedMember.badge,
                managementTeam: detailedMember.managementTeam,
                attendanceRecords: detailedMember.attendanceRecords,
                penaltyHistory: detailedMember.penaltyHistory,
                canViewPenaltyHistory: detailedMember.canViewPenaltyHistory,
                generationPoints: detailedMember.generationPoints
            )
        }

        selectedMember = detailedMember
    }

    /// 포인트 기록을 삭제합니다.
    @MainActor
    func deletePoint(
        member: MemberManagementItem,
        history: OperatorMemberPenaltyHistory
    ) async -> String? {
        guard let challengerPointId = history.challengerPointId else {
            return "삭제할 포인트 ID를 찾을 수 없습니다."
        }

        isDeletingPoint = true
        defer { isDeletingPoint = false }

        do {
            try await fetchMembersUseCase.deletePoint(
                challengerPointId: challengerPointId
            )
            try await reloadMembersAndReselect(member: member)
            NotificationCenter.default.post(name: .memberPenaltyUpdated, object: nil)
            return nil
        } catch let error as DomainError {
            return error.userMessage
        } catch let error as RepositoryError {
            return deletePointFailureMessage(from: error)
        } catch let error as NetworkError {
            return deletePointFailureMessage(from: error)
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Activity",
                    action: "deletePoint"
                )
            )
            return "포인트 삭제에 실패했습니다. 잠시 후 다시 시도해주세요."
        }
    }

    @MainActor
    private func reloadMembersAndReselect(
        member: MemberManagementItem
    ) async throws {
        let updatedMembers = try await fetchMembersUseCase.execute()
        membersState = .loaded(updatedMembers)
        guard let resolvedMember = resolveMember(
            in: updatedMembers,
            from: member
        ) else {
            selectedMember = nil
            return
        }

        let detailedMember = await fetchMemberDetail(
            for: resolvedMember
        )

        selectedMember = memberWithStableSheetIdentity(
            base: member,
            updated: detailedMember
        )
    }

    /// 멤버의 상세 정보(출석 기록, 포인트 히스토리, 기수 포인트)를 조회합니다.
    @MainActor
    private func fetchMemberDetail(
        for member: MemberManagementItem
    ) async -> MemberManagementItem {
        guard let challengerId = member.challengerID else {
            return member
        }

        let memberId = member.memberID ?? 0

        async let pointHistoryTask = try? fetchMembersUseCase.fetchPointHistory(
            challengerId: challengerId
        )
        async let genPointsTask = try? fetchMembersUseCase
            .fetchGenerationPointSummaries(memberId: memberId)

        let records: [MemberAttendanceRecord] = []
        let pointHistory = await pointHistoryTask ?? member.penaltyHistory
        let generationPoints = await genPointsTask ?? []

        let penaltyItems = pointHistory.filter { !$0.pointType.isReward }
        let rewardItems = pointHistory.filter { $0.pointType.isReward }
        let totalPenalty = penaltyItems.isEmpty
            ? member.penalty
            : penaltyItems.reduce(0) { $0 + $1.penaltyScore }
        let totalReward = rewardItems.reduce(0) { $0 + $1.penaltyScore }

        return MemberManagementItem(
            id: member.id,
            memberID: member.memberID,
            challengerID: member.challengerID,
            profile: member.profile,
            name: member.name,
            nickname: member.nickname,
            generation: member.generation,
            school: member.school,
            position: member.position,
            part: member.part,
            penalty: totalPenalty,
            rewardPoints: totalReward,
            badge: member.badge,
            managementTeam: member.managementTeam,
            attendanceRecords: records,
            penaltyHistory: pointHistory,
            canViewPenaltyHistory: true,
            generationPoints: generationPoints
        )
    }

    private func resolveMember(
        in members: [MemberManagementItem],
        from target: MemberManagementItem
    ) -> MemberManagementItem? {
        members.first(where: {
            if let targetMemberId = target.memberID,
               let memberId = $0.memberID,
               targetMemberId == memberId {
                return true
            }

            if let targetChallengerId = target.challengerID,
               let challengerId = $0.challengerID,
               targetChallengerId == challengerId {
                return true
            }

            return false
        })
    }

    private func memberWithStableSheetIdentity(
        base: MemberManagementItem,
        updated: MemberManagementItem
    ) -> MemberManagementItem {
        MemberManagementItem(
            id: base.id,
            memberID: updated.memberID,
            challengerID: updated.challengerID,
            profile: updated.profile,
            name: updated.name,
            nickname: updated.nickname,
            generation: updated.generation,
            school: updated.school,
            position: updated.position,
            part: updated.part,
            penalty: updated.penalty,
            rewardPoints: updated.rewardPoints,
            badge: updated.badge,
            managementTeam: updated.managementTeam,
            attendanceRecords: updated.attendanceRecords,
            penaltyHistory: updated.penaltyHistory,
            canViewPenaltyHistory: base.canViewPenaltyHistory || updated.canViewPenaltyHistory,
            generationPoints: updated.generationPoints
        )
    }

    private func deletePointFailureMessage(from error: RepositoryError) -> String {
        if case .serverError(_, let message) = error,
           let message,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return error.userMessage
    }

    private func deletePointFailureMessage(from error: NetworkError) -> String {
        guard case .requestFailed(_, let data) = error else {
            return error.userMessage
        }
        return decodeServerMessage(from: data) ?? error.userMessage
    }

    private func decodeServerMessage(from data: Data?) -> String? {
        guard let data,
              let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) else {
            return nil
        }

        let candidates = [payload.message, payload.result]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

}

private struct ServerErrorPayload: Decodable {
    let message: String?
    let result: String?
}
