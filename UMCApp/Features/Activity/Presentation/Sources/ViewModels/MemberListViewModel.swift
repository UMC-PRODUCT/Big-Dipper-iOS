//
//  MemberListViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/28/26.
//

import ActivityDomain
import CoreDomain
import Foundation
import UMCFoundation

/// 멤버 목록 화면의 상태를 관리하는 ViewModel
///
/// 멤버 목록 조회(무한스크롤 페이지네이션), 상벌점 부여·삭제, 멤버 상세 시트 표시를
/// 담당합니다. 모든 서버 식별자는 `String` 으로 통일되며, 데이터 접근은
/// `FetchMembersUseCaseProtocol` 에만 의존합니다.
@MainActor
@Observable
final class MemberListViewModel {

    // MARK: - Dependency

    private let fetchMembersUseCase: FetchMembersUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let userSessionManager: UserSessionManager

    // MARK: - Property

    var searchText: String = ""
    var selectedMember: MemberManagementItem?
    private(set) var membersState: Loadable<[MemberManagementItem]> = .idle
    var alertPrompt: AlertPrompt?
    private(set) var isSubmittingPoint: Bool = false
    private(set) var isDeletingPoint: Bool = false
    private(set) var isLoadingMemberDetail: Bool = false
    private(set) var isLoadingNextPage: Bool = false
    private(set) var hasMorePages: Bool = true
    private var currentPage: Int = 0

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

    // MARK: - Computed Property

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

    // MARK: - Function

    /// 멤버 첫 페이지를 조회합니다.
    ///
    /// `.task` 라이프사이클 취소(빠른 화면 이탈·탭 전환·pull-to-refresh 재요청)로 던져지는
    /// `CancellationError`/`NSURLErrorCancelled` 는 실패가 아니므로 이전 상태로 롤백한다
    /// (형제 `ChallengerStudyViewModel` house 패턴). 재진입 가드로 중복 로드도 차단.
    func fetchMembers() async {
        if membersState.isLoading { return }

        let previousState = membersState
        membersState = .loading
        currentPage = 0
        hasMorePages = true
        do {
            let page = try await fetchMembersUseCase.executePage(page: 0)
            membersState = .loaded(page.members)
            hasMorePages = page.hasNext
            currentPage = page.currentPage
        } catch is CancellationError {
            membersState = previousState
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            membersState = previousState
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

    /// 다음 페이지를 조회하여 기존 목록에 추가합니다.
    func fetchNextPage() async {
        guard hasMorePages, !isLoadingNextPage else { return }
        guard case .loaded(let existing) = membersState else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let nextPage = currentPage + 1
            let page = try await fetchMembersUseCase.executePage(
                page: nextPage
            )
            // memberID 가 둘 다 있을 때만 중복으로 판단한다. memberID 가 nil 인 멤버를
            // nil == nil 로 묶어 일괄 제거하지 않도록 non-nil 일 때만 비교한다.
            let deduplicatedMembers = page.members.filter { newMember in
                guard let newMemberID = newMember.memberID else { return true }
                return !existing.contains { $0.memberID == newMemberID }
            }
            membersState = .loaded(existing + deduplicatedMembers)
            hasMorePages = page.hasNext
            currentPage = page.currentPage
        } catch {
            // 다음 페이지 실패 시 기존 데이터 유지
        }
    }

    /// 멤버에게 포인트를 부여합니다.
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

        // 서버 부여는 이미 성공. 목록 새로고침은 best-effort 로 처리한다.
        // 새로고침 실패를 부여 실패로 보고하면 사용자가 재시도해 중복 부여로 이어지므로,
        // 부여 성공/알림과 새로고침을 분리한다.
        await refreshMember(after: member)
        NotificationCenter.default.post(name: .memberPenaltyUpdated, object: nil)
        return true
    }

    /// 챌린저 멤버 상세 시트를 표시합니다.
    func openChallengerMemberDetail(
        _ member: MemberManagementItem
    ) async {
        guard member.challengerID != nil else {
            selectedMember = member
            return
        }

        isLoadingMemberDetail = true
        defer { isLoadingMemberDetail = false }

        let memberId = member.memberID ?? ""
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

        // 서버 삭제는 이미 성공. 목록 새로고침은 best-effort (실패해도 삭제 결과는 유효).
        await refreshMember(after: member)
        NotificationCenter.default.post(name: .memberPenaltyUpdated, object: nil)
        return nil
    }

    /// 상벌점 mutation 후 로컬 상태를 갱신한다.
    ///
    /// 상벌점을 부여/삭제한 **그 멤버 한 명만** 단건 재조회해 로컬 목록과 선택 상태를
    /// 교체한다. 전체 페이지를 처음부터 다시 받지 않으므로 목록이 길어져도 갱신 비용이
    /// 일정하다. mutation 은 이미 서버에 반영됐고 상세 조회는 실패 시 원본 멤버를 그대로
    /// 돌려주므로(`fetchMemberDetail`), 이 경로는 사용자 흐름을 막지 않는 best-effort 다.
    private func refreshMember(after member: MemberManagementItem) async {
        let detailedMember = await fetchMemberDetail(for: member)

        // 로컬 목록에서 해당 멤버 항목만 교체한다(전체 페이지 재요청 없음).
        if case .loaded(var members) = membersState,
           let index = members.firstIndex(where: { isSameMember($0, as: member) }) {
            members[index] = detailedMember
            membersState = .loaded(members)
        }

        // 상세 시트가 이 멤버를 표시 중이면 선택 상태도 갱신한다(시트 정체성 유지).
        if let selected = selectedMember, isSameMember(selected, as: member) {
            selectedMember = memberWithStableSheetIdentity(
                base: selected,
                updated: detailedMember
            )
        }
    }

    /// 두 멤버가 같은 대상인지 서버 식별자로 판별한다.
    ///
    /// `memberID` 가 양쪽 모두 있으면 그것으로, 아니면 `challengerID` 로 비교한다.
    private func isSameMember(
        _ lhs: MemberManagementItem,
        as rhs: MemberManagementItem
    ) -> Bool {
        if let lhsMemberID = lhs.memberID,
           let rhsMemberID = rhs.memberID,
           lhsMemberID == rhsMemberID {
            return true
        }
        if let lhsChallengerID = lhs.challengerID,
           let rhsChallengerID = rhs.challengerID,
           lhsChallengerID == rhsChallengerID {
            return true
        }
        return false
    }

    /// 멤버의 상세 정보(출석 기록, 포인트 히스토리, 기수 포인트)를 조회합니다.
    private func fetchMemberDetail(
        for member: MemberManagementItem
    ) async -> MemberManagementItem {
        guard let challengerId = member.challengerID else {
            return member
        }

        let memberId = member.memberID ?? ""

        async let pointHistoryTask = try? fetchMembersUseCase.fetchPointHistory(
            challengerId: challengerId
        )
        async let genPointsTask = try? fetchMembersUseCase
            .fetchGenerationPointSummaries(memberId: memberId)
        async let recordsTask = try? fetchMembersUseCase
            .fetchAttendanceRecords(memberId: memberId)

        let records = await recordsTask ?? member.attendanceRecords
        let pointHistory = await pointHistoryTask ?? member.penaltyHistory
        let generationPoints = await genPointsTask ?? []

        let penaltyItems = pointHistory.filter { !$0.pointType.isReward }
        let rewardItems = pointHistory.filter { $0.pointType.isReward }
        let totalPenalty = penaltyItems.isEmpty
            ? member.penalty
            : penaltyItems.reduce(0) { $0 + $1.penaltyScore }
        // 상점도 벌점과 대칭 폴백: 재조회 히스토리에 상점 항목이 없으면 기존 상점을 보존한다
        // (단건 재조회가 리스트 카드에도 반영되므로, 벌점만 있는 히스토리로 상점을 0 으로
        // 지우지 않도록). penaltyItems 폴백과 동형.
        let totalReward = rewardItems.isEmpty
            ? member.rewardPoints
            : rewardItems.reduce(0) { $0 + $1.penaltyScore }

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

// MARK: - ServerErrorPayload

private struct ServerErrorPayload: Decodable {
    let message: String?
    let result: String?
}
