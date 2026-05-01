//
//  OperatorStudyManagementViewModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/8/26.
//

import Foundation

/// 스터디 관리 화면의 상태를 관리하는 ViewModel
///
/// 제출 현황 조회, 스터디 그룹 CRUD, 리뷰/베스트 워크북 선정을 처리합니다.
@Observable
final class OperatorStudyManagementViewModel {
    // MARK: - Property

    private enum Constants {
        static let groupManagementPageSize = 20
    }

    private var container: DIContainer
    private var errorHandler: ErrorHandler
    private var useCase: FetchStudyMembersUseCaseProtocol

    /// 스터디원 목록 로딩 상태
    private(set) var membersState: Loadable<[StudyMemberItem]> = .idle

    /// 스터디 그룹 관리 로딩 상태
    private(set) var studyGroupDetailsState: Loadable<[StudyGroupInfo]> = .idle

    /// 스터디 그룹 필터 목록
    private(set) var studyGroups: [StudyGroupItem] = [.all]

    /// 현재 선택된 스터디 그룹 필터
    var selectedStudyGroup: StudyGroupItem = .all

    /// 주차 목록
    private(set) var weeks: [Int] = []

    /// 현재 선택된 주차
    var selectedWeek: Int = 1

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

    /// 시트 표시 상태
    var selectedMemberForReview: StudyMemberItem?

    /// 베스트 워크북 선정 대상 멤버
    var selectedMemberForBest: StudyMemberItem?

    /// 확인 다이얼로그
    var alertPrompt: AlertPrompt?

    /// 시트 dismiss 후 표시할 대기 중인 AlertPrompt
    private var pendingAlertPrompt: AlertPrompt?

    /// 필터링 전 전체 멤버 목록
    private var allMembers: [StudyMemberItem] = []

    /// 그룹 상세 목록 최초 로드 여부
    private var hasLoadedStudyGroupDetails = false

    /// 스터디 그룹 상세 목록 다음 페이지 커서
    private var studyGroupDetailsNextCursor: Int?

    /// 스터디 그룹 상세 목록 다음 페이지 존재 여부
    private var studyGroupDetailsHasNext = false

    /// 제출 현황 탭 필터(그룹/주차) 최초 로드 여부
    private var hasLoadedSubmissionFilters = false

    /// 현재 사용자 기수 ID (UserDefaults 기준)
    var currentGisuId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
    }

    // MARK: - Initializer

    /// - Parameters:
    ///   - container: 의존성 주입 컨테이너
    ///   - errorHandler: 전역 에러 핸들러
    ///   - useCase: 스터디 멤버 조회 UseCase
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        useCase: FetchStudyMembersUseCaseProtocol
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.useCase = useCase
    }

    // MARK: - Function

    /// 스터디 멤버(제출 현황) 조회
    @MainActor
    func fetchMembers() async {
        await fetchSubmissionMembers()
    }

    /// 제출 현황 탭 진입/필터 변경 시 호출
    @MainActor
    func fetchSubmissionMembers() async {
        membersState = .loading

        do {
            let shouldReloadSubmissionFilters = !hasLoadedSubmissionFilters
            if shouldReloadSubmissionFilters {
                let fetchedGroups = try await useCase.fetchStudyGroups()
                studyGroups = normalizeStudyGroups(fetchedGroups)
                weeks = try await useCase.fetchWeeks()
                if !weeks.contains(selectedWeek), let firstWeek = weeks.first {
                    selectedWeek = firstWeek
                }

                if !studyGroups.contains(selectedStudyGroup) {
                    selectedStudyGroup = .all
                }
                hasLoadedSubmissionFilters = true
            }

            let selectedGroupId = selectedStudyGroup == .all
            ? nil
            : Int(selectedStudyGroup.serverID)
            let members = try await useCase.fetchMembers(
                week: selectedWeek,
                studyGroupId: selectedGroupId
            )
            allMembers = members
            filterMembers()
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
                .unknown(message: "제출 현황 데이터를 불러오지 못했습니다.")
            )
        }
    }

    /// 스터디 그룹 관리 탭 진입 시 그룹 목록 및 상세 조회
    @MainActor
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
            hasLoadedStudyGroupDetails = true
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
    @MainActor
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
            alertPrompt = AlertPrompt(
                title: "불러오지 못했어요",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "fetchMoreStudyGroupManagement"
            ))
        }
    }

    /// Sheet dismiss 시 호출 — 변경된 스터디원 목록을 서버에 반영
    @MainActor
    func applySelectedChallengers() async {
        guard let targetGroup = memberUpdateTargetGroup,
              let index = studyGroupDetails.firstIndex(
                  where: { $0.id == targetGroup.id }
              )
        else {
            selectedChallengers = []
            memberUpdateTargetGroup = nil
            return
        }

        guard let serverGroupId = Int(targetGroup.serverID) else {
            alertPrompt = AlertPrompt(
                title: "변경 실패",
                message: "유효하지 않은 그룹 ID입니다.",
                positiveBtnTitle: "확인"
            )
            selectedChallengers = []
            memberUpdateTargetGroup = nil
            return
        }

        let currentChallengerIDs = Set(
            studyGroupDetails[index]
                .members
                .compactMap(\.challengerID)
                .filter { $0 > 0 }
        )
        let resolvedChallengerIDs = await resolveChallengerIDs(
            from: selectedChallengers
        )
        let unresolvedCount = selectedChallengers.count - resolvedChallengerIDs.count
        guard unresolvedCount == 0 else {
            alertPrompt = AlertPrompt(
                title: "변경 실패",
                message: "선택한 멤버의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요.",
                positiveBtnTitle: "확인"
            )
            selectedChallengers = []
            memberUpdateTargetGroup = nil
            return
        }
        let updatedChallengerIDs = Set(
            selectedChallengers
                .compactMap { resolvedChallengerIDs[$0.selectionKey] }
                .filter { $0 > 0 }
        )

        if currentChallengerIDs == updatedChallengerIDs {
            selectedChallengers = []
            memberUpdateTargetGroup = nil
            return
        }

        let toAdd = updatedChallengerIDs.subtracting(currentChallengerIDs)
        let toRemove = currentChallengerIDs.subtracting(updatedChallengerIDs)

        var failures: [String] = []

        for challengerId in toAdd {
            do {
                try await useCase.addStudyGroupMember(
                    groupId: serverGroupId,
                    memberId: challengerId
                )
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append("멤버 추가 실패")
            }
        }

        for challengerId in toRemove {
            do {
                try await useCase.removeStudyGroupMember(
                    groupId: serverGroupId,
                    memberId: challengerId
                )
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append("멤버 제거 실패")
            }
        }

        if failures.isEmpty {
            studyGroupDetails[index].members = selectedChallengers.map {
                StudyGroupMember(
                    serverID: $0.memberId,
                    challengerID: resolvedChallengerIDs[$0.selectionKey],
                    memberID: Int($0.memberId),
                    name: $0.name,
                    nickname: $0.nickname,
                    university: $0.schoolName,
                    profileImageURL: $0.profileImage
                )
            }
        } else {
            alertPrompt = AlertPrompt(
                title: "일부 변경 실패",
                message: failures.joined(separator: "\n"),
                positiveBtnTitle: "확인"
            )
            refreshStudyGroupManagementDataInBackground()
        }

        selectedChallengers = []
        memberUpdateTargetGroup = nil
    }

    /// 멘토 시트 dismiss 시 호출 — 변경된 멘토 목록을 서버에 반영
    @MainActor
    func applySelectedMentors() async {
        guard let targetGroup = mentorUpdateTargetGroup,
              let index = studyGroupDetails.firstIndex(
                  where: { $0.id == targetGroup.id }
              )
        else {
            selectedMentors = []
            mentorUpdateTargetGroup = nil
            return
        }

        guard let serverGroupId = Int(targetGroup.serverID) else {
            alertPrompt = AlertPrompt(
                title: "변경 실패",
                message: "유효하지 않은 그룹 ID입니다.",
                positiveBtnTitle: "확인"
            )
            selectedMentors = []
            mentorUpdateTargetGroup = nil
            return
        }

        guard !selectedMentors.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "변경 실패",
                message: "최소 1명의 멘토가 필요합니다.",
                positiveBtnTitle: "확인"
            )
            selectedMentors = []
            mentorUpdateTargetGroup = nil
            return
        }

        let currentChallengerIDs = Set(
            studyGroupDetails[index]
                .mentors
                .compactMap(\.challengerID)
                .filter { $0 > 0 }
        )
        let resolvedChallengerIDs = await resolveChallengerIDs(
            from: selectedMentors
        )
        let unresolvedCount = selectedMentors.count - resolvedChallengerIDs.count
        guard unresolvedCount == 0 else {
            alertPrompt = AlertPrompt(
                title: "변경 실패",
                message: "선택한 멘토의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요.",
                positiveBtnTitle: "확인"
            )
            selectedMentors = []
            mentorUpdateTargetGroup = nil
            return
        }
        let updatedChallengerIDs = Set(
            selectedMentors
                .compactMap { resolvedChallengerIDs[$0.selectionKey] }
                .filter { $0 > 0 }
        )

        if currentChallengerIDs == updatedChallengerIDs {
            selectedMentors = []
            mentorUpdateTargetGroup = nil
            return
        }

        let toAdd = updatedChallengerIDs.subtracting(currentChallengerIDs)
        let toRemove = currentChallengerIDs.subtracting(updatedChallengerIDs)

        var failures: [String] = []

        for challengerId in toAdd {
            do {
                try await useCase.addStudyGroupMentor(
                    groupId: serverGroupId,
                    mentorId: challengerId
                )
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append("멘토 추가 실패")
            }
        }

        for challengerId in toRemove {
            do {
                try await useCase.removeStudyGroupMentor(
                    groupId: serverGroupId,
                    mentorId: challengerId
                )
            } catch let error as DomainError {
                failures.append(error.userMessage)
            } catch {
                failures.append("멘토 제거 실패")
            }
        }

        if failures.isEmpty {
            studyGroupDetails[index].mentors = selectedMentors.map {
                StudyGroupMember(
                    serverID: $0.memberId,
                    challengerID: resolvedChallengerIDs[$0.selectionKey],
                    memberID: Int($0.memberId),
                    name: $0.name,
                    nickname: $0.nickname,
                    university: $0.schoolName,
                    profileImageURL: $0.profileImage,
                    role: .leader
                )
            }
        } else {
            alertPrompt = AlertPrompt(
                title: "일부 변경 실패",
                message: failures.joined(separator: "\n"),
                positiveBtnTitle: "확인"
            )
            refreshStudyGroupManagementDataInBackground()
        }

        selectedMentors = []
        mentorUpdateTargetGroup = nil
    }

    /// 멤버 단건 삭제 (chip context menu)
    @MainActor
    func removeMember(_ member: StudyGroupMember, from group: StudyGroupInfo) async {
        guard let serverGroupId = Int(group.serverID),
              let challengerId = member.challengerID, challengerId > 0,
              let index = studyGroupDetails.firstIndex(where: { $0.id == group.id })
        else {
            alertPrompt = AlertPrompt(
                title: "삭제 실패",
                message: "유효하지 않은 식별자입니다.",
                positiveBtnTitle: "확인"
            )
            return
        }

        do {
            try await useCase.removeStudyGroupMember(
                groupId: serverGroupId,
                memberId: challengerId
            )
            studyGroupDetails[index].members.removeAll { $0.id == member.id }
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "삭제 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
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
    @MainActor
    func removeMentor(_ mentor: StudyGroupMember, from group: StudyGroupInfo) async {
        guard let index = studyGroupDetails.firstIndex(where: { $0.id == group.id }) else {
            return
        }

        guard studyGroupDetails[index].mentors.count > 1 else {
            alertPrompt = AlertPrompt(
                title: "삭제 불가",
                message: "최소 1명의 멘토는 유지되어야 합니다.",
                positiveBtnTitle: "확인"
            )
            return
        }

        guard let serverGroupId = Int(group.serverID),
              let challengerId = mentor.challengerID, challengerId > 0
        else {
            alertPrompt = AlertPrompt(
                title: "삭제 실패",
                message: "유효하지 않은 식별자입니다.",
                positiveBtnTitle: "확인"
            )
            return
        }

        do {
            try await useCase.removeStudyGroupMentor(
                groupId: serverGroupId,
                mentorId: challengerId
            )
            studyGroupDetails[index].mentors.removeAll { $0.id == mentor.id }
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "삭제 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "removeStudyGroupMentor"
            ))
        }
    }

    /// 그룹 이름 수정 적용
    /// - Parameters:
    ///   - groupID: 수정할 그룹 ID
    ///   - name: 새 그룹명
    @MainActor
    func updateGroup(
        groupID: UUID,
        name: String
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "수정 실패",
                message: "그룹 이름을 입력해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        guard let oldGroup = studyGroupDetails.first(where: { $0.id == groupID }) else {
            alertPrompt = AlertPrompt(
                title: "수정 실패",
                message: "그룹 정보를 찾을 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        guard let serverGroupId = Int(oldGroup.serverID) else {
            alertPrompt = AlertPrompt(
                title: "수정 실패",
                message: "유효한 그룹 식별자가 아닙니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        do {
            try await useCase.updateStudyGroup(
                groupId: serverGroupId,
                name: trimmedName
            )
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "수정 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "updateStudyGroup"
            ))
            return false
        }

        guard let index = studyGroupDetails.firstIndex(where: { $0.id == groupID }) else {
            alertPrompt = AlertPrompt(
                title: "수정 실패",
                message: "그룹이 삭제되어 수정할 수 없습니다.",
                positiveBtnTitle: "확인"
            )
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

    /// 그룹 편집 시트 표시
    func showEditSheet(for group: StudyGroupInfo) {
        editingName = group.name
        editingGroup = group
    }

    /// 멤버 추가 시트 표시
    func showAddMemberSheet(for group: StudyGroupInfo) {
        memberUpdateTargetGroup = group
        selectedChallengers = group.members.map { member in
            ChallengerInfo(
                memberId: member.memberID.map(String.init) ?? member.serverID,
                challengerId: member.challengerID
                    ?? member.memberID
                    ?? Int(member.serverID)
                    ?? 0,
                gen: 0,
                name: member.name,
                nickname: member.nickname ?? member.name,
                schoolName: member.university,
                profileImage: member.profileImageURL,
                part: group.part
            )
        }
        addMemberGroup = group
    }

    /// 멘토 추가 시트 표시
    func showAddMentorSheet(for group: StudyGroupInfo) {
        mentorUpdateTargetGroup = group
        selectedMentors = group.mentors.map { mentor in
            ChallengerInfo(
                memberId: mentor.memberID.map(String.init) ?? mentor.serverID,
                challengerId: mentor.challengerID
                    ?? mentor.memberID
                    ?? Int(mentor.serverID)
                    ?? 0,
                gen: 0,
                name: mentor.name,
                nickname: mentor.nickname ?? mentor.name,
                schoolName: mentor.university,
                profileImage: mentor.profileImageURL,
                part: group.part
            )
        }
        addMentorGroup = group
    }

    /// 새 스터디 그룹 생성 (ChallengerInfo → StudyGroupMember 변환)
    /// - Parameters:
    ///   - name: 그룹명
    ///   - part: 파트
    ///   - mentors: 담당 파트장(멘토) 목록 (1명 이상)
    ///   - members: 스터디원 목록
    @MainActor
    func createGroup(
        name: String,
        part: UMCPartType,
        mentors: [ChallengerInfo],
        members: [ChallengerInfo]
    ) async -> Bool {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: "그룹 이름을 입력해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        guard !mentors.isEmpty else {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: "최소 1명의 담당 파트장(멘토)이 필요합니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        let gisuId = currentGisuId
        guard gisuId > 0 else {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: "현재 기수 정보를 확인할 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        let resolvedChallengerIDs = await resolveChallengerIDs(
            from: mentors + members
        )

        let unresolvedMentor = mentors.contains {
            resolvedChallengerIDs[$0.selectionKey] == nil
        }
        guard !unresolvedMentor else {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: "선택한 멘토의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        let unresolvedMemberExists = members.contains {
            resolvedChallengerIDs[$0.selectionKey] == nil
        }
        guard !unresolvedMemberExists else {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: "초대한 멤버의 챌린저 ID를 확인하지 못했습니다. 다시 시도해 주세요.",
                positiveBtnTitle: "확인"
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
                mentorIds: mentorIds,
                members: members,
                resolvedChallengerIDs: resolvedChallengerIDs
            )
            refreshStudyGroupManagementDataInBackground()

            return true
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "그룹 생성 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
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

    private func presentStudyGroupCreateAlert(from error: NetworkError) -> Bool {
        guard case .requestFailed(let statusCode, let data) = error else {
            return false
        }

        let message = studyGroupCreateFailureMessage(
            statusCode: statusCode,
            data: data
        ) ?? decodeServerMessage(from: data)

        guard let message else { return false }

        alertPrompt = AlertPrompt(
            title: "그룹 생성 실패",
            message: message,
            positiveBtnTitle: "확인"
        )
        return true
    }

    private func presentStudyGroupCreateAlert(from error: RepositoryError) -> Bool {
        guard case .serverError(_, let message) = error,
              let message,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        alertPrompt = AlertPrompt(
            title: "그룹 생성 실패",
            message: message,
            positiveBtnTitle: "확인"
        )
        return true
    }

    private func studyGroupCreateFailureMessage(
        statusCode: Int,
        data: Data?
    ) -> String? {
        guard statusCode == 403 else { return nil }

        let payload = decodeServerErrorPayload(from: data)
        let errorCode = payload?.code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard errorCode == "AUTHORIZATION-0002" || !errorCode.isEmpty else {
            return nil
        }

        return "현재 계정 권한으로는 스터디 그룹을 생성할 수 없습니다.\n서버 권한 수정 전까지 총괄 계정에서는 생성이 제한될 수 있습니다."
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

    private func appendCreatedGroupToLocalState(
        name: String,
        part: UMCPartType,
        mentors: [ChallengerInfo],
        mentorIds: [Int],
        members: [ChallengerInfo],
        resolvedChallengerIDs: [String: Int]
    ) {
        let localServerID = "new_\(UUID().uuidString)"
        let mentorMembers: [StudyGroupMember] = mentors.map { mentor in
            StudyGroupMember(
                serverID: mentor.memberId,
                challengerID: resolvedChallengerIDs[mentor.selectionKey],
                memberID: Int(mentor.memberId),
                name: mentor.name,
                nickname: mentor.nickname,
                university: mentor.schoolName,
                profileImageURL: mentor.profileImage,
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
            members: members.compactMap {
                !mentorMemberIds.contains($0.memberId) ? StudyGroupMember(
                    serverID: $0.memberId,
                    challengerID: resolvedChallengerIDs[$0.selectionKey],
                    memberID: Int($0.memberId),
                    name: $0.name,
                    nickname: $0.nickname,
                    university: $0.schoolName,
                    profileImageURL: $0.profileImage
                ) : nil
            }
        )

        let localItem = StudyGroupItem(
            serverID: localServerID,
            name: name,
            iconName: "person.2.fill",
            part: nil
        )

        if !studyGroups.contains(localItem) {
            var updatedGroups = studyGroups.filter { $0 != .all }
            updatedGroups.insert(localItem, at: 0)
            studyGroups = normalizeStudyGroups(updatedGroups)
        }

        switch studyGroupDetailsState {
        case .loaded:
            studyGroupDetails.insert(localGroup, at: 0)
            studyGroupDetailsState = .loaded(studyGroupDetails)
            hasLoadedStudyGroupDetails = true
        case .idle:
            studyGroupDetails = [localGroup]
            studyGroupDetailsState = .loaded(studyGroupDetails)
            hasLoadedStudyGroupDetails = true
        case .loading, .failed:
            break
        }
    }

    private func refreshStudyGroupManagementDataInBackground() {
        Task { [weak self] in
            guard let self else { return }

            if let updatedGroups = try? await self.useCase.fetchStudyGroups() {
                await MainActor.run {
                    self.studyGroups = self.normalizeStudyGroups(updatedGroups)
                    if !self.studyGroups.contains(self.selectedStudyGroup) {
                        self.selectedStudyGroup = .all
                    }
                    self.hasLoadedSubmissionFilters = false
                }
            }

            if let firstPage = try? await self.useCase.fetchStudyGroupDetailsPage(
                cursor: nil,
                size: Constants.groupManagementPageSize
            ) {
                await MainActor.run {
                    self.studyGroupDetails = firstPage.content
                    self.studyGroupDetailsNextCursor = firstPage.nextCursor
                    self.studyGroupDetailsHasNext = firstPage.hasNext
                    self.studyGroupDetailsState = .loaded(firstPage.content)
                    self.hasLoadedStudyGroupDetails = true
                }
            }
        }
    }

    /// 그룹 삭제 API 호출
    func deleteGroup(_ group: StudyGroupInfo) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard let serverGroupId = Int(group.serverID) else {
                self.alertPrompt = AlertPrompt(
                    title: "삭제 실패",
                    message: "유효하지 않은 그룹 ID입니다.",
                    positiveBtnTitle: "확인"
                )
                return
            }

            do {
                try await self.useCase.deleteStudyGroup(
                    groupId: serverGroupId
                )

                self.removeGroupFromLocalState(group.serverID)
            } catch let error as DomainError {
                self.alertPrompt = AlertPrompt(
                    title: "삭제 실패",
                    message: error.userMessage,
                    positiveBtnTitle: "확인"
                )
            } catch {
                self.errorHandler.handle(error, context: ErrorContext(
                    feature: "Activity",
                    action: "deleteStudyGroup"
                ))
            }
        }
    }

    /// 주차 필터 변경 시 멤버 목록 갱신
    func selectWeek(_ week: Int) {
        Task { @MainActor [weak self] in
            await self?.fetchMembers()
        }
    }

    /// 스터디 그룹 필터 변경 시 멤버 목록 갱신
    func selectStudyGroup(_ group: StudyGroupItem) {
        Task { @MainActor [weak self] in
            await self?.fetchMembers()
        }
    }

    /// 시트 dismiss 후 대기 중인 AlertPrompt를 표시
    func presentPendingAlert() {
        guard let pending = pendingAlertPrompt else { return }
        pendingAlertPrompt = nil
        alertPrompt = pending
    }

    /// 검토 시트 표시를 위해 제출 URL을 조회한 뒤 멤버를 선택 상태로 설정
    /// - Parameter member: 대상 멤버
    func openReviewSheet(for member: StudyMemberItem) {
        guard let challengerWorkbookId = member.challengerWorkbookId else {
            selectedMemberForReview = member
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let submissionURL = try await self.useCase.fetchWorkbookSubmissionURL(
                    challengerWorkbookId: challengerWorkbookId
                )
                let resolvedMember = StudyMemberItem(
                    id: member.id,
                    serverID: member.serverID,
                    challengerWorkbookId: member.challengerWorkbookId,
                    studyGroupId: member.studyGroupId,
                    name: member.name,
                    nickname: member.nickname,
                    part: member.part,
                    university: member.university,
                    studyTopic: member.studyTopic,
                    week: member.week,
                    profileImageURL: member.profileImageURL,
                    submissionURL: submissionURL ?? member.submissionURL,
                    isBestWorkbook: member.isBestWorkbook
                )
                self.selectedMemberForReview = resolvedMember
            } catch {
                self.selectedMemberForReview = member
            }
        }
    }

    /// 스터디 승인(PASS) 제출
    /// - Parameters:
    ///   - member: 대상 멤버
    ///   - feedback: 피드백 내용
    func submitReviewApproval(
        member: StudyMemberItem,
        feedback: String
    ) async -> Bool {
        await submitReview(
            member: member,
            feedback: feedback,
            isApproved: true
        )
    }

    /// 스터디 반려 확인 다이얼로그 준비
    /// - Parameters:
    ///   - member: 대상 멤버
    ///   - feedback: 피드백 내용
    func submitReviewRejection(
        member: StudyMemberItem,
        feedback: String
    ) async -> Bool {
        await submitReview(
            member: member,
            feedback: feedback,
            isApproved: false
        )
    }

    /// 베스트 워크북 선정 제출
    /// - Parameters:
    ///   - member: 대상 멤버
    ///   - recommendation: 추천 사유
    func submitBestWorkbookSelection(
        member: StudyMemberItem,
        recommendation: String
    ) async -> Bool {
        await submitBestWorkbook(
            member: member,
            recommendation: recommendation
        )
    }

    /// 해당 멤버의 스터디 그룹에 이미 베스트 워크북이 선정되었는지 확인
    /// - Parameter member: 확인 대상 멤버
    /// - Returns: 같은 그룹에 이미 베스트 워크북이 있으면 true
    func isBestSelectionDisabled(for member: StudyMemberItem) -> Bool {
        guard let groupId = member.studyGroupId else { return false }
        return allMembers.contains { other in
            other.studyGroupId == groupId
                && other.isBestWorkbook
                && other.id != member.id
        }
    }

    /// 베스트 워크북 선정 불가 안내 AlertPrompt 표시
    func showBestSelectionDisabledAlert() {
        alertPrompt = AlertPrompt(
            title: "베스트 워크북 선정 불가",
            message: "이 스터디 그룹에는 이미 베스트 워크북이 선정되었습니다.",
            positiveBtnTitle: "확인"
        )
    }

    private func submitReview(
        member: StudyMemberItem,
        feedback: String,
        isApproved: Bool
    ) async -> Bool {
        guard let challengerWorkbookId = member.challengerWorkbookId else {
            alertPrompt = AlertPrompt(
                title: "검토 실패",
                message: "워크북 식별자를 찾을 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        do {
            try await useCase.reviewWorkbook(
                challengerWorkbookId: challengerWorkbookId,
                isApproved: isApproved,
                feedback: feedback
            )
            removeMember(member)
            return true
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "검토 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "reviewWorkbook"
            ))
            return false
        }
    }

    private func submitBestWorkbook(
        member: StudyMemberItem,
        recommendation: String
    ) async -> Bool {
        guard let challengerWorkbookId = member.challengerWorkbookId else {
            alertPrompt = AlertPrompt(
                title: "선정 실패",
                message: "워크북 식별자를 찾을 수 없습니다.",
                positiveBtnTitle: "확인"
            )
            return false
        }

        do {
            try await useCase.selectBestWorkbook(
                challengerWorkbookId: challengerWorkbookId,
                bestReason: recommendation
            )
            markAsBestWorkbook(member)
            return true
        } catch let error as DomainError {
            alertPrompt = AlertPrompt(
                title: "선정 실패",
                message: error.userMessage,
                positiveBtnTitle: "확인"
            )
            return false
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Activity",
                action: "selectBestWorkbook"
            ))
            return false
        }
    }

    // MARK: - Private

    /// 서버 제출 완료된 멤버를 목록에서 제거
    private func removeMember(_ member: StudyMemberItem) {
        allMembers.removeAll { $0.id == member.id }
        filterMembers()
    }

    private func resolveChallengerIDs(
        from challengers: [ChallengerInfo]
    ) async -> [String: Int] {
        var resolved: [String: Int] = [:]
        for challenger in challengers {
            if let id = await resolveChallengerID(for: challenger) {
                resolved[challenger.selectionKey] = id
            }
        }
        return resolved
    }

    private func resolveChallengerID(
        for challenger: ChallengerInfo
    ) async -> Int? {
        let memberIdInt = Int(challenger.memberId) ?? 0
        let hasDistinctChallengerID = challenger.challengerId > 0 &&
            challenger.challengerId != memberIdInt
        if hasDistinctChallengerID {
            return challenger.challengerId
        }

        do {
            if let resolvedID = try await useCase.resolveChallengerId(
                memberId: memberIdInt,
                preferredGeneration: challenger.gen
            ),
               resolvedID > 0 {
                return resolvedID
            }
        } catch {
            // 조회 실패 시 아래 fallback 규칙으로 처리
        }

        if memberIdInt <= 0, challenger.challengerId > 0 {
            return challenger.challengerId
        }

        return nil
    }

    /// 멤버를 베스트 워크북으로 표시
    private func markAsBestWorkbook(_ member: StudyMemberItem) {
        guard let index = allMembers.firstIndex(
            where: { $0.id == member.id }
        ) else { return }
        allMembers[index].isBestWorkbook = true
        filterMembers()
    }

    /// 선택된 스터디 그룹과 주차에 따라 멤버 필터링
    private func filterMembers() {
        membersState = .loaded(allMembers)
    }

    /// 툴바 메뉴에 항상 `전체 스터디 그룹`이 포함되도록 정규화
    private func normalizeStudyGroups(
        _ groups: [StudyGroupItem]
    ) -> [StudyGroupItem] {
        var normalized: [StudyGroupItem] = [.all]
        for group in groups where group != .all {
            if !normalized.contains(group) {
                normalized.append(group)
            }
        }
        return normalized
    }

    /// 삭제 성공 후 로컬 상태에서 그룹 삭제 반영
    private func removeGroupFromLocalState(_ serverID: String) {
        studyGroupDetails.removeAll { $0.serverID == serverID }
        studyGroups.removeAll {
            $0.serverID == serverID && $0 != .all
        }
        studyGroupDetailsState = .loaded(studyGroupDetails)

        if selectedStudyGroup.serverID == serverID {
            selectedStudyGroup = .all
        }
    }

}
