//
//  OperatorStudyManagementViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/27/26.
//

import ActivityDomain
import CoreDomain
import Foundation
import UMCFoundation

/// 운영진 스터디 관리 화면의 상태를 관리하는 ViewModel
///
/// 스터디 그룹 CRUD(생성/수정/삭제) 및 멘토·멤버 변경을 처리합니다.
/// 모든 액션은 `OperatorStudyManagementUseCaseProtocol` 에만 의존하며(Repository 직접 의존 금지),
/// 서버 식별자는 전 레이어 `String` 으로 통일합니다.
@MainActor
@Observable
final class OperatorStudyManagementViewModel {

    // MARK: - Property

    private enum Constants {
        static let groupManagementPageSize = 20
        /// 낙관적 삽입으로 만든 로컬 placeholder 그룹의 serverID 접두사.
        /// 서버 호출 대상이 아님을 구분하는 표식 — 백그라운드 새로고침으로 곧 교체됩니다.
        static let localGroupIDPrefix = "new_"
    }

    private let errorHandler: ErrorHandler
    private let useCase: OperatorStudyManagementUseCaseProtocol

    /// 현재 사용자 기수 ID 제공자 (서버 응답 `String`) — 테스트에서 주입 가능.
    private let gisuIdProvider: () -> String?

    /// 스터디 그룹 관리 로딩 상태
    private(set) var studyGroupDetailsState: Loadable<[StudyGroupInfo]> = .idle

    /// 스터디 그룹 관리 상태
    private(set) var studyGroupDetails: [StudyGroupInfo] = []

    /// 스터디 그룹 목록 추가 페이지 로딩 여부
    private(set) var isLoadingMoreStudyGroupDetails = false

    /// 편집 중인 그룹 (시트 표시용)
    var editingGroup: StudyGroupInfo?

    /// 편집 시트 이름 입력 상태
    var editingName: String = ""

    /// 멤버 추가 대상 그룹 (시트 표시용)
    var addMemberGroup: StudyGroupInfo?

    /// 멤버 변경 API 호출 대상 그룹 (시트 dismiss 이후 사용)
    private var memberUpdateTargetGroup: StudyGroupInfo?

    /// 시트에서 선택된 챌린저 목록
    var selectedChallengers: [ChallengerInfo] = []

    /// 멘토 추가 대상 그룹 (시트 표시용)
    var addMentorGroup: StudyGroupInfo?

    /// 멘토 변경 API 호출 대상 그룹 (시트 dismiss 이후 사용)
    private var mentorUpdateTargetGroup: StudyGroupInfo?

    /// 멘토 시트에서 선택된 챌린저 목록
    var selectedMentors: [ChallengerInfo] = []

    /// 확인 다이얼로그
    var alertPrompt: AlertPrompt?

    /// 스터디 그룹 상세 목록 다음 페이지 커서 (서버 응답 `String`)
    private var studyGroupDetailsNextCursor: String?

    /// 스터디 그룹 상세 목록 다음 페이지 존재 여부
    private var studyGroupDetailsHasNext = false

    // MARK: - Initializer

    /// - Parameters:
    ///   - errorHandler: 전역 에러 핸들러
    ///   - useCase: 운영진 스터디 관리 UseCase
    ///   - gisuIdProvider: 현재 기수 ID 제공자 (기본값: `AppStorageKey.gisuId` 저장값)
    init(
        errorHandler: ErrorHandler,
        useCase: OperatorStudyManagementUseCaseProtocol,
        gisuIdProvider: @escaping () -> String? = {
            OperatorStudyManagementViewModel.storedGisuId()
        }
    ) {
        self.errorHandler = errorHandler
        self.useCase = useCase
        self.gisuIdProvider = gisuIdProvider
    }

    // MARK: - Function (조회 / 페이지네이션)

    /// 스터디 그룹 관리 탭 진입 시 그룹 목록 및 상세 조회
    func fetchGroupManagementData() async {
        studyGroupDetailsState = .loading
        isLoadingMoreStudyGroupDetails = false
        studyGroupDetailsNextCursor = nil
        studyGroupDetailsHasNext = false

        do {
            let firstPage = try await useCase.fetchStudyGroupDetailsPage(
                cursor: nil,
                size: Constants.groupManagementPageSize
            )
            studyGroupDetails = firstPage.content
            studyGroupDetailsNextCursor = firstPage.nextCursor
            studyGroupDetailsHasNext = firstPage.hasNext
            studyGroupDetailsState = .loaded(studyGroupDetails)
        } catch let error as AppError {
            studyGroupDetailsState = .failed(error)
        } catch let error as DomainError {
            studyGroupDetailsState = .failed(.domain(error))
        } catch let error as NetworkError {
            studyGroupDetailsState = .failed(.network(error))
        } catch let error as RepositoryError {
            studyGroupDetailsState = .failed(.repository(error))
        } catch {
            studyGroupDetailsState = .failed(.unknown(
                message: "스터디 그룹 관리 데이터를 불러오지 못했습니다."
            ))
        }
    }

    /// 스터디 그룹 관리 목록 마지막 카드 도달 시 다음 페이지를 로드합니다.
    /// - Parameter currentGroupID: 현재 표시된 카드의 로컬 식별자
    func loadMoreGroupManagementDataIfNeeded(currentGroupID: UUID) async {
        guard case .loaded = studyGroupDetailsState else { return }
        guard studyGroupDetails.last?.id == currentGroupID else { return }
        guard studyGroupDetailsHasNext else { return }
        guard !isLoadingMoreStudyGroupDetails else { return }

        isLoadingMoreStudyGroupDetails = true
        defer { isLoadingMoreStudyGroupDetails = false }

        do {
            let nextPage = try await useCase.fetchStudyGroupDetailsPage(
                cursor: studyGroupDetailsNextCursor,
                size: Constants.groupManagementPageSize
            )

            let existingServerIDs = Set(studyGroupDetails.map(\.serverID))
            let newGroups = nextPage.content.filter {
                !existingServerIDs.contains($0.serverID)
            }
            if !newGroups.isEmpty {
                studyGroupDetails.append(contentsOf: newGroups)
                studyGroupDetailsState = .loaded(studyGroupDetails)
            }

            studyGroupDetailsNextCursor = nextPage.nextCursor
            studyGroupDetailsHasNext = nextPage.hasNext
        } catch let error as DomainError {
            presentAlert(title: "불러오지 못했어요", message: error.userMessage)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "fetchMoreStudyGroupManagement"
            ))
        }
    }

    // MARK: - Function (멤버 / 멘토 변경)

    /// Sheet dismiss 시 호출 — 변경된 스터디원 목록을 서버에 반영
    func applySelectedChallengers() async {
        guard let targetGroup = memberUpdateTargetGroup,
              let index = studyGroupDetails.firstIndex(
                  where: { $0.id == targetGroup.id }
              )
        else {
            resetMemberSelection()
            return
        }

        guard isPersistedServerGroup(targetGroup.serverID) else {
            presentAlert(title: "변경 실패", message: "유효하지 않은 그룹 ID입니다.")
            resetMemberSelection()
            return
        }
        let serverGroupId = targetGroup.serverID

        let currentChallengerIDs = Set(
            studyGroupDetails[index].members
                .compactMap(\.challengerID)
                .filter(Self.isUsableID)
        )
        let resolvedChallengerIDs = await resolveChallengerIDs(from: selectedChallengers)
        let unresolvedCount = selectedChallengers.count - resolvedChallengerIDs.count
        guard unresolvedCount == 0 else {
            presentAlert(
                title: "변경 실패",
                message: "선택한 멤버의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요."
            )
            resetMemberSelection()
            return
        }
        let updatedChallengerIDs = Set(
            selectedChallengers
                .compactMap { resolvedChallengerIDs[$0.selectionKey] }
                .filter(Self.isUsableID)
        )

        if currentChallengerIDs == updatedChallengerIDs {
            resetMemberSelection()
            return
        }

        let toAdd = updatedChallengerIDs.subtracting(currentChallengerIDs)
        let toRemove = currentChallengerIDs.subtracting(updatedChallengerIDs)

        let failures = await applyMembershipChanges(
            groupId: serverGroupId,
            toAdd: toAdd,
            toRemove: toRemove,
            add: useCase.addStudyGroupMember,
            remove: useCase.removeStudyGroupMember,
            addFailureMessage: "멤버 추가 실패",
            removeFailureMessage: "멤버 제거 실패"
        )

        if failures.isEmpty {
            studyGroupDetails[index].members = selectedChallengers.map {
                studyGroupMember(from: $0, resolvedChallengerIDs: resolvedChallengerIDs)
            }
        } else {
            presentAlert(
                title: "일부 변경 실패",
                message: failures.joined(separator: "\n")
            )
            refreshStudyGroupManagementDataInBackground()
        }

        resetMemberSelection()
    }

    /// 멘토 시트 dismiss 시 호출 — 변경된 멘토 목록을 서버에 반영
    func applySelectedMentors() async {
        guard let targetGroup = mentorUpdateTargetGroup,
              let index = studyGroupDetails.firstIndex(
                  where: { $0.id == targetGroup.id }
              )
        else {
            resetMentorSelection()
            return
        }

        guard isPersistedServerGroup(targetGroup.serverID) else {
            presentAlert(title: "변경 실패", message: "유효하지 않은 그룹 ID입니다.")
            resetMentorSelection()
            return
        }
        let serverGroupId = targetGroup.serverID

        guard !selectedMentors.isEmpty else {
            presentAlert(title: "변경 실패", message: "최소 1명의 멘토가 필요합니다.")
            resetMentorSelection()
            return
        }

        let currentChallengerIDs = Set(
            studyGroupDetails[index].mentors
                .compactMap(\.challengerID)
                .filter(Self.isUsableID)
        )
        let resolvedChallengerIDs = await resolveChallengerIDs(from: selectedMentors)
        let unresolvedCount = selectedMentors.count - resolvedChallengerIDs.count
        guard unresolvedCount == 0 else {
            presentAlert(
                title: "변경 실패",
                message: "선택한 멘토의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요."
            )
            resetMentorSelection()
            return
        }
        let updatedChallengerIDs = Set(
            selectedMentors
                .compactMap { resolvedChallengerIDs[$0.selectionKey] }
                .filter(Self.isUsableID)
        )

        if currentChallengerIDs == updatedChallengerIDs {
            resetMentorSelection()
            return
        }

        let toAdd = updatedChallengerIDs.subtracting(currentChallengerIDs)
        let toRemove = currentChallengerIDs.subtracting(updatedChallengerIDs)

        let failures = await applyMembershipChanges(
            groupId: serverGroupId,
            toAdd: toAdd,
            toRemove: toRemove,
            add: useCase.addStudyGroupMentor,
            remove: useCase.removeStudyGroupMentor,
            addFailureMessage: "멘토 추가 실패",
            removeFailureMessage: "멘토 제거 실패"
        )

        if failures.isEmpty {
            studyGroupDetails[index].mentors = selectedMentors.map {
                studyGroupMember(
                    from: $0,
                    resolvedChallengerIDs: resolvedChallengerIDs,
                    role: .leader
                )
            }
        } else {
            presentAlert(
                title: "일부 변경 실패",
                message: failures.joined(separator: "\n")
            )
            refreshStudyGroupManagementDataInBackground()
        }

        resetMentorSelection()
    }

    /// 멤버 단건 삭제 (chip context menu)
    func removeMember(_ member: StudyGroupMember, from group: StudyGroupInfo) async {
        guard isPersistedServerGroup(group.serverID),
              let challengerId = member.challengerID, Self.isUsableID(challengerId),
              let index = studyGroupDetails.firstIndex(where: { $0.id == group.id })
        else {
            presentAlert(title: "삭제 실패", message: "유효하지 않은 식별자입니다.")
            return
        }

        do {
            try await useCase.removeStudyGroupMember(
                groupId: group.serverID,
                memberId: challengerId
            )
            studyGroupDetails[index].members.removeAll { $0.id == member.id }
        } catch let error as DomainError {
            presentAlert(title: "삭제 실패", message: error.userMessage)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "removeStudyGroupMember"
            ))
        }
    }

    /// 멘토 단건 삭제 (chip context menu)
    ///
    /// 마지막 멘토 삭제는 차단합니다.
    func removeMentor(_ mentor: StudyGroupMember, from group: StudyGroupInfo) async {
        guard let index = studyGroupDetails.firstIndex(where: { $0.id == group.id }) else {
            return
        }

        guard studyGroupDetails[index].mentors.count > 1 else {
            presentAlert(title: "삭제 불가", message: "최소 1명의 멘토는 유지되어야 합니다.")
            return
        }

        guard isPersistedServerGroup(group.serverID),
              let challengerId = mentor.challengerID, Self.isUsableID(challengerId)
        else {
            presentAlert(title: "삭제 실패", message: "유효하지 않은 식별자입니다.")
            return
        }

        do {
            try await useCase.removeStudyGroupMentor(
                groupId: group.serverID,
                mentorId: challengerId
            )
            studyGroupDetails[index].mentors.removeAll { $0.id == mentor.id }
        } catch let error as DomainError {
            presentAlert(title: "삭제 실패", message: error.userMessage)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "removeStudyGroupMentor"
            ))
        }
    }

    // MARK: - Function (그룹 CRUD)

    /// 그룹 이름 수정 적용
    /// - Parameters:
    ///   - groupID: 수정할 그룹 ID
    ///   - name: 새 그룹명
    func updateGroup(groupID: UUID, name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presentAlert(title: "수정 실패", message: "그룹 이름을 입력해 주세요.")
            return false
        }

        guard let oldGroup = studyGroupDetails.first(where: { $0.id == groupID }) else {
            presentAlert(title: "수정 실패", message: "그룹 정보를 찾을 수 없습니다.")
            return false
        }

        guard isPersistedServerGroup(oldGroup.serverID) else {
            presentAlert(title: "수정 실패", message: "유효한 그룹 식별자가 아닙니다.")
            return false
        }

        do {
            try await useCase.updateStudyGroup(
                groupId: oldGroup.serverID,
                name: trimmedName
            )
        } catch let error as DomainError {
            presentAlert(title: "수정 실패", message: error.userMessage)
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "updateStudyGroup"
            ))
            return false
        }

        guard let index = studyGroupDetails.firstIndex(where: { $0.id == groupID }) else {
            presentAlert(title: "수정 실패", message: "그룹이 삭제되어 수정할 수 없습니다.")
            return false
        }

        let old = studyGroupDetails[index]
        studyGroupDetails[index] = StudyGroupInfo(
            id: old.id,
            serverID: old.serverID,
            name: trimmedName,
            part: old.part,
            createdDate: old.createdDate,
            mentors: old.mentors,
            members: old.members
        )
        return true
    }

    /// 새 스터디 그룹 생성 (ChallengerInfo → StudyGroupMember 변환)
    /// - Parameters:
    ///   - name: 그룹명
    ///   - part: 파트
    ///   - mentors: 담당 파트장(멘토) 목록 (1명 이상)
    ///   - members: 스터디원 목록
    func createGroup(
        name: String,
        part: UMCPartType,
        mentors: [ChallengerInfo],
        members: [ChallengerInfo]
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presentAlert(title: "그룹 생성 실패", message: "그룹 이름을 입력해 주세요.")
            return false
        }

        guard !mentors.isEmpty else {
            presentAlert(
                title: "그룹 생성 실패",
                message: "최소 1명의 담당 파트장(멘토)이 필요합니다."
            )
            return false
        }

        guard let gisuId = gisuIdProvider(), Self.isUsableID(gisuId) else {
            presentAlert(
                title: "그룹 생성 실패",
                message: "현재 기수 정보를 확인할 수 없습니다."
            )
            return false
        }

        let resolvedChallengerIDs = await resolveChallengerIDs(from: mentors + members)

        let unresolvedMentor = mentors.contains {
            resolvedChallengerIDs[$0.selectionKey] == nil
        }
        guard !unresolvedMentor else {
            presentAlert(
                title: "그룹 생성 실패",
                message: "선택한 멘토의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요."
            )
            return false
        }

        let unresolvedMemberExists = members.contains {
            resolvedChallengerIDs[$0.selectionKey] == nil
        }
        guard !unresolvedMemberExists else {
            presentAlert(
                title: "그룹 생성 실패",
                message: "초대한 멤버의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요."
            )
            return false
        }

        let mentorIds = mentors.compactMap { resolvedChallengerIDs[$0.selectionKey] }
        let memberIds = members
            .compactMap { resolvedChallengerIDs[$0.selectionKey] }
            .filter { !mentorIds.contains($0) }

        do {
            try await useCase.createStudyGroup(
                gisuId: gisuId,
                name: trimmedName,
                part: part,
                memberIds: memberIds,
                mentorIds: mentorIds
            )
            appendCreatedGroupToLocalState(
                name: trimmedName,
                part: part,
                mentors: mentors,
                members: members,
                resolvedChallengerIDs: resolvedChallengerIDs
            )
            refreshStudyGroupManagementDataInBackground()

            return true
        } catch let error as DomainError {
            presentAlert(title: "그룹 생성 실패", message: error.userMessage)
            return false
        } catch let error as NetworkError {
            if presentStudyGroupCreateAlert(from: error) {
                return false
            }
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "createStudyGroup"
            ))
            return false
        } catch let error as RepositoryError {
            if presentStudyGroupCreateAlert(from: error) {
                return false
            }
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "createStudyGroup"
            ))
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "createStudyGroup"
            ))
            return false
        }
    }

    /// 그룹 삭제 API 호출
    func deleteGroup(_ group: StudyGroupInfo) async {
        guard isPersistedServerGroup(group.serverID) else {
            presentAlert(title: "삭제 실패", message: "유효하지 않은 그룹 ID입니다.")
            return
        }

        do {
            try await useCase.deleteStudyGroup(groupId: group.serverID)
            removeGroupFromLocalState(group.serverID)
        } catch let error as DomainError {
            presentAlert(title: "삭제 실패", message: error.userMessage)
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "deleteStudyGroup"
            ))
        }
    }

    // MARK: - Function (시트 표시)

    /// 그룹 편집 시트 표시
    func showEditSheet(for group: StudyGroupInfo) {
        editingName = group.name
        editingGroup = group
    }

    /// 멤버 추가 시트 표시
    func showAddMemberSheet(for group: StudyGroupInfo) {
        memberUpdateTargetGroup = group
        selectedChallengers = group.members.map { challengerInfo(from: $0, part: group.part) }
        addMemberGroup = group
    }

    /// 멘토 추가 시트 표시
    func showAddMentorSheet(for group: StudyGroupInfo) {
        mentorUpdateTargetGroup = group
        selectedMentors = group.mentors.map { challengerInfo(from: $0, part: group.part) }
        addMentorGroup = group
    }

    // MARK: - Private (챌린저 ID 해석)

    private func resolveChallengerIDs(
        from challengers: [ChallengerInfo]
    ) async -> [String: String] {
        var resolved: [String: String] = [:]
        for challenger in challengers {
            if let id = await resolveChallengerID(for: challenger) {
                resolved[challenger.selectionKey] = id
            }
        }
        return resolved
    }

    private func resolveChallengerID(for challenger: ChallengerInfo) async -> String? {
        // memberId 와 다른 명시적 챌린저 ID 가 있으면 그대로 사용
        let hasDistinctChallengerID = Self.isUsableID(challenger.challengerId)
            && challenger.challengerId != challenger.memberId
        if hasDistinctChallengerID {
            return challenger.challengerId
        }

        do {
            if let resolvedID = try await useCase.resolveChallengerId(
                memberId: challenger.memberId,
                preferredGeneration: challenger.gen.isEmpty ? nil : challenger.gen
            ), Self.isUsableID(resolvedID) {
                return resolvedID
            }
        } catch {
            // 해석 실패는 무시하고 폴백으로 진행
        }

        // memberId 가 유효하지 않으면 challengerId 폴백
        if !Self.isUsableID(challenger.memberId), Self.isUsableID(challenger.challengerId) {
            return challenger.challengerId
        }

        return nil
    }

    // MARK: - Private (로컬 상태 반영)

    private func appendCreatedGroupToLocalState(
        name: String,
        part: UMCPartType,
        mentors: [ChallengerInfo],
        members: [ChallengerInfo],
        resolvedChallengerIDs: [String: String]
    ) {
        let localServerID = "\(Constants.localGroupIDPrefix)\(UUID().uuidString)"
        let mentorMembers: [StudyGroupMember] = mentors.map { mentor in
            studyGroupMember(
                from: mentor,
                resolvedChallengerIDs: resolvedChallengerIDs,
                role: .leader
            )
        }
        let mentorMemberIds = Set(mentors.map(\.memberId))
        let localGroup = StudyGroupInfo(
            serverID: localServerID,
            name: name,
            part: part,
            createdDate: Date(),
            mentors: mentorMembers,
            members: members.compactMap { challenger in
                guard !mentorMemberIds.contains(challenger.memberId) else { return nil }
                return studyGroupMember(
                    from: challenger,
                    resolvedChallengerIDs: resolvedChallengerIDs
                )
            }
        )

        switch studyGroupDetailsState {
        case .loaded:
            studyGroupDetails.insert(localGroup, at: 0)
            studyGroupDetailsState = .loaded(studyGroupDetails)
        case .idle:
            studyGroupDetails = [localGroup]
            studyGroupDetailsState = .loaded(studyGroupDetails)
        case .loading, .failed:
            break
        }
    }

    private func refreshStudyGroupManagementDataInBackground() {
        // 새로고침 전에 사용자가 스크롤로 로드해 둔 항목 수(로드 윈도우)를 기억한다.
        // 낙관적 placeholder(`new_`)는 아직 서버에 없으므로 목표 길이 계산에서 제외한다.
        let targetCount = max(
            studyGroupDetails.filter { isPersistedServerGroup($0.serverID) }.count,
            Constants.groupManagementPageSize
        )

        Task { [weak self] in
            guard let self else { return }

            do {
                // 첫 페이지만 덮어써 뒤쪽 페이지를 잘라내던 문제를 방지한다.
                // 첫 페이지부터 다시 페이지네이션해 기존 로드 윈도우 길이를 복원한다.
                var restored: [StudyGroupInfo] = []
                var seenServerIDs = Set<String>()
                var cursor: String?
                var hasNext = true

                repeat {
                    let page = try await self.useCase.fetchStudyGroupDetailsPage(
                        cursor: cursor,
                        size: Constants.groupManagementPageSize
                    )
                    for group in page.content {
                        guard seenServerIDs.insert(group.serverID).inserted else { continue }
                        restored.append(group)
                    }
                    cursor = page.nextCursor
                    hasNext = page.hasNext
                } while hasNext && restored.count < targetCount

                self.studyGroupDetails = restored
                self.studyGroupDetailsNextCursor = cursor
                self.studyGroupDetailsHasNext = hasNext
                self.studyGroupDetailsState = .loaded(restored)
            } catch {
                // 생성 자체는 성공했으나 목록 재동기화에 실패한 경우.
                // 낙관적 `new_` placeholder 가 남아 관리(수정/삭제)가 막히므로,
                // 실패를 삼키지 않고 사용자에게 노출해 수동 새로고침을 유도한다.
                self.errorHandler.handle(error, context: ErrorContext(
                    feature: "Activity",
                    action: "refreshStudyGroupManagementAfterCreate"
                ))
            }
        }
    }

    /// 삭제 성공 후 로컬 상태에서 그룹 삭제 반영
    private func removeGroupFromLocalState(_ serverID: String) {
        studyGroupDetails.removeAll { $0.serverID == serverID }
        studyGroupDetailsState = .loaded(studyGroupDetails)
    }

    // MARK: - Private (그룹 생성 실패 메시지)

    private func presentStudyGroupCreateAlert(from error: NetworkError) -> Bool {
        guard case .requestFailed(let statusCode, let data) = error else {
            return false
        }

        // 로컬 Alert 로 소화하는 대상은 403(권한) 에러뿐이다.
        // 그 외 상태코드(401 세션 만료·404·409·5xx 등)는 서버 응답 본문에 message 필드가
        // 있더라도 여기서 처리하지 않고 false 를 반환해, 호출부가 errorHandler(로깅/세션 처리)로
        // 흘려보내도록 한다.
        guard statusCode == 403 else { return false }

        let message = authorizationFailureMessage(from: data)
            ?? decodeServerMessage(from: data)

        guard let message else { return false }

        presentAlert(title: "그룹 생성 실패", message: message)
        return true
    }

    private func presentStudyGroupCreateAlert(from error: RepositoryError) -> Bool {
        guard case .serverError(_, let message) = error,
              let message,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        presentAlert(title: "그룹 생성 실패", message: message)
        return true
    }

    /// 403 그룹 생성 실패 중 `AUTHORIZATION-0002` 코드에 대한 권한 안내 메시지.
    ///
    /// 호출부(`presentStudyGroupCreateAlert(from:)`)가 이미 `statusCode == 403` 을 보장하므로
    /// 여기서는 에러 코드만 판별한다. 다른 403 코드는 nil 을 반환해, 호출부가 서버 메시지
    /// fallback(`decodeServerMessage`)으로 처리하게 한다.
    private func authorizationFailureMessage(from data: Data?) -> String? {
        let payload = decodeServerErrorPayload(from: data)
        let errorCode = payload?.code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard errorCode == "AUTHORIZATION-0002" else {
            return nil
        }

        return """
        현재 계정 권한으로는 스터디 그룹을 생성할 수 없습니다.
        서버 권한 수정 전까지 총괄 계정에서는 생성이 제한될 수 있습니다.
        """
    }

    private func decodeServerMessage(from data: Data?) -> String? {
        let payload = decodeServerErrorPayload(from: data)
        let message = payload?.message ?? payload?.result ?? payload?.error
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func decodeServerErrorPayload(from data: Data?) -> ServerErrorPayload? {
        guard let data,
              let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) else {
            return nil
        }
        return payload
    }

    private struct ServerErrorPayload: Decodable {
        let code: String?
        let message: String?
        let result: String?
        let error: String?
    }

    // MARK: - Private (Helper)

    /// 멤버/멘토 추가·제거를 순차 적용하고 실패 메시지를 모읍니다.
    /// `add`/`remove` 는 대상 UseCase 메서드(`(groupId, challengerId)`)이며,
    /// 실패 시 도메인 메시지 또는 기본 메시지를 누적해 반환합니다.
    private func applyMembershipChanges(
        groupId: String,
        toAdd: Set<String>,
        toRemove: Set<String>,
        add: (String, String) async throws -> Void,
        remove: (String, String) async throws -> Void,
        addFailureMessage: String,
        removeFailureMessage: String
    ) async -> [String] {
        var failures: [String] = []
        for challengerId in toAdd {
            do {
                try await add(groupId, challengerId)
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append(addFailureMessage)
            }
        }
        for challengerId in toRemove {
            do {
                try await remove(groupId, challengerId)
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append(removeFailureMessage)
            }
        }
        return failures
    }

    /// 유효한 서버 식별자(비어있지 않고 `"0"` 이 아님) 여부.
    /// 레거시 `Int > 0` 판정을 `String` 세계로 옮긴 것 — `"0"`/빈 문자열은 미해석 ID 로 간주.
    private static func isUsableID(_ id: String) -> Bool {
        !id.isEmpty && id != "0"
    }

    /// 서버에 실재하는 그룹인지 — 낙관적 삽입 placeholder 는 서버 호출 대상이 아님.
    private func isPersistedServerGroup(_ serverID: String) -> Bool {
        !serverID.isEmpty && !serverID.hasPrefix(Constants.localGroupIDPrefix)
    }

    private func presentAlert(title: String, message: String) {
        alertPrompt = AlertPrompt(
            title: title,
            message: message,
            positiveBtnTitle: "확인"
        )
    }

    private func resetMemberSelection() {
        selectedChallengers = []
        memberUpdateTargetGroup = nil
    }

    private func resetMentorSelection() {
        selectedMentors = []
        mentorUpdateTargetGroup = nil
    }

    private func challengerInfo(
        from member: StudyGroupMember,
        part: UMCPartType
    ) -> ChallengerInfo {
        ChallengerInfo(
            memberId: member.memberID ?? member.serverID,
            challengerId: member.challengerID ?? member.memberID ?? member.serverID,
            gen: "",
            name: member.name,
            nickname: member.nickname ?? member.name,
            schoolName: member.university,
            profileImage: member.profileImageURL,
            part: part
        )
    }

    private func studyGroupMember(
        from challenger: ChallengerInfo,
        resolvedChallengerIDs: [String: String],
        role: StudyGroupMember.MemberRole = .member
    ) -> StudyGroupMember {
        StudyGroupMember(
            serverID: challenger.memberId,
            challengerID: resolvedChallengerIDs[challenger.selectionKey],
            memberID: challenger.memberId,
            name: challenger.name,
            nickname: challenger.nickname,
            university: challenger.schoolName,
            profileImageURL: challenger.profileImage,
            role: role
        )
    }

    private nonisolated static func storedGisuId(_ defaults: UserDefaults = .standard) -> String? {
        if let value = defaults.string(forKey: AppStorageKey.gisuId), !value.isEmpty {
            return value
        }
        let legacyInt = defaults.integer(forKey: AppStorageKey.gisuId)
        return legacyInt > 0 ? String(legacyInt) : nil
    }
}
