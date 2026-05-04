//
//  StudyRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation
import Moya

/// Study Repository 실제 API 구현체
final class StudyRepository: StudyRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    private enum Constants {
        static let myStudyGroupsPageSize = 100
    }

    private struct StudyGroupItemsPage {
        let groups: [StudyGroupItem]
        let hasNext: Bool
        let nextCursor: Int?
    }

    // MARK: - Init

    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Curriculum

    func fetchCurriculumData(weekNo: Int?) async throws -> CurriculumData {
        guard let gisuId = preferredGisuId, gisuId > 0 else {
            throw DomainError.curriculumUnavailableForGeneration
        }
        let part = resolvedPartAPIValue
        let response = try await adapter.request(
            StudyRouter.getCurriculum(gisuId: gisuId, part: part, weekNo: weekNo)
        )
        let apiResponse = try decoder.decode(
            APIResponse<CurriculumDTO>.self,
            from: response.data
        )
        let dto = try apiResponse.unwrap()
        return dto.toDomain(part: part)
    }

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        try await fetchCurriculumData(weekNo: nil).progress
    }

    func fetchMissions() async throws -> [MissionCardModel] {
        try await fetchCurriculumData(weekNo: nil).missions
    }

    // MARK: - 운영진 스터디 관리 (Fallback)

    func fetchStudyMembers(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem] {
        if let studyGroupId {
            return try await fetchMembersByGroup(
                week: week,
                studyGroupId: studyGroupId
            )
        }

        // `전체` 선택 시에도 접근 가능한 그룹 ID를 역할별 API에서 먼저 수집해
        // 그룹별 제출 현황을 조회한 뒤 병합합니다.
        let accessibleGroupIDs = try await fetchAccessibleStudyGroupIDsForSubmission()
        guard !accessibleGroupIDs.isEmpty else {
            // 그룹 ID를 구하지 못한 경우에만 레거시 동작으로 폴백
            return try await fetchMembersByGroup(
                week: week,
                studyGroupId: nil
            )
        }

        var aggregatedMembers: [StudyMemberItem] = []
        for groupID in accessibleGroupIDs {
            let members = try await fetchMembersByGroup(
                week: week,
                studyGroupId: groupID
            )
            aggregatedMembers.append(contentsOf: members)
        }

        return deduplicatedMembersPreservingOrder(aggregatedMembers)
    }

    func fetchStudyGroups() async throws -> [StudyGroupItem] {
        var lastError: Error?

        if isSchoolCoreRole {
            do {
                if let groups = try await fetchStudyGroupsByNames() {
                    return groups
                }
            } catch {
                lastError = error
            }

            do {
                if let groups = try await fetchMyStudyGroups() {
                    return groups
                }
            } catch {
                if lastError == nil {
                    lastError = error
                }
            }
        } else {
            do {
                if let groups = try await fetchMyStudyGroups() {
                    if groups.contains(where: { $0 != .all }) {
                        return groups
                    }

                    // 멀티 역할 사용자에서 role 캐시가 단일값으로 저장된 경우 보정
                    // (`/study-groups`가 비어있고 `/study-groups/names`는 조회 가능한 케이스)
                    if let groupsByNames = try? await fetchStudyGroupsByNames(),
                       groupsByNames.contains(where: { $0 != .all }) {
                        return groupsByNames
                    }

                    return groups
                }
            } catch {
                lastError = error
            }

            do {
                if let groupsByNames = try await fetchStudyGroupsByNames(),
                   groupsByNames.contains(where: { $0 != .all }) {
                    return groupsByNames
                }
            } catch {
                if lastError == nil {
                    lastError = error
                }
            }
        }

        if let lastError {
            throw lastError
        }
        throw RepositoryError.serverError(
            code: nil,
            message: "스터디 그룹 정보를 불러오지 못했습니다."
        )
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        var allDetails: [StudyGroupInfo] = []
        var cursor: Int? = nil
        var hasNext = true

        while hasNext {
            let page = try await fetchStudyGroupDetailsPage(
                cursor: cursor,
                size: Constants.myStudyGroupsPageSize
            )
            allDetails.append(contentsOf: page.content)

            hasNext = page.hasNext
            cursor = page.nextCursor
            if hasNext && cursor == nil {
                break
            }
        }

        return allDetails
    }

    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        let groupsPage = try await fetchStudyGroupItemsPage(
            cursor: cursor,
            size: size
        )

        let detailDTOs = await fetchStudyGroupDetailDTOs(
            groups: groupsPage.groups
        )
        guard !detailDTOs.isEmpty else {
            return StudyGroupDetailsPage(
                content: [],
                hasNext: groupsPage.hasNext,
                nextCursor: groupsPage.nextCursor
            )
        }

        let memberIDs = Array(
            Set(
                detailDTOs.flatMap { item in
                    item.dto.mentors.map(\.memberId) + item.dto.members.map(\.memberId)
                }
            )
        )
        let bestWorkbookPointByMemberID = await fetchBestWorkbookPoints(
            memberIDs: memberIDs
        )

        let details = detailDTOs.map { item in
            item.dto.toDomain(
                defaultGroupName: item.groupName,
                bestWorkbookPointByMemberID: bestWorkbookPointByMemberID
            )
        }

        return StudyGroupDetailsPage(
            content: details,
            hasNext: groupsPage.hasNext,
            nextCursor: groupsPage.nextCursor
        )
    }

    func fetchWeeks() async throws -> [Int] {
        let part = resolvedPartAPIValue
        let response = try await adapter.request(
            StudyRouter.getCurriculumWeeks(part: part)
        )
        let apiResponse = try decoder.decode(
            APIResponse<CurriculumWeeksDTO>.self,
            from: response.data
        )
        let weeks = Array(Set(
            try apiResponse.unwrap()
                .weeks
                .compactMap { Int($0.weekNo) }
        )).sorted()

        return weeks
    }

    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int? {
        let profile = try await fetchMemberManagementProfile(
            memberId: memberId
        )
        let records = profile.challengerRecords.filter {
            $0.memberId == memberId && $0.challengerId > 0
        }

        if let preferredGeneration, preferredGeneration > 0,
           let matchedRecord = records.first(where: { $0.gisu == preferredGeneration }) {
            return matchedRecord.challengerId
        }

        if let preferredGisuId,
           let matchedRecord = records.first(where: { $0.gisuId == preferredGisuId }) {
            return matchedRecord.challengerId
        }

        return records.first?.challengerId
    }

    func fetchWorkbookSubmissionURL(
        challengerWorkbookId: Int
    ) async throws -> String? {
        let response = try await adapter.request(
            StudyRouter.getWorkbookSubmission(
                challengerWorkbookId: challengerWorkbookId
            )
        )

        let dto: WorkbookSubmissionDetailDTO
        if let apiResponse = try? decoder.decode(
            APIResponse<WorkbookSubmissionDetailDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            dto = wrapped
        } else {
            dto = try decoder.decode(
                WorkbookSubmissionDetailDTO.self,
                from: response.data
            )
        }

        guard let submission = dto.submission,
              !submission.isEmpty else {
            return nil
        }
        return submission
    }

    func reviewWorkbook(
        challengerWorkbookId: Int,
        isApproved: Bool,
        feedback: String
    ) async throws {
        let status = isApproved ? "PASS" : "FAIL"
        let response = try await adapter.request(
            StudyRouter.reviewWorkbook(
                challengerWorkbookId: challengerWorkbookId,
                body: WorkbookReviewRequestDTO(
                    status: status,
                    feedback: feedback
                )
            )
        )

        if response.data.isEmpty {
            return
        }
        if let apiResponse = try? decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        ) {
            try apiResponse.validateSuccess()
        }
    }

    func selectBestWorkbook(
        challengerWorkbookId: Int,
        bestReason: String
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.selectBestWorkbook(
                challengerWorkbookId: challengerWorkbookId,
                body: BestWorkbookSelectionRequestDTO(bestReason: bestReason)
            )
        )

        if response.data.isEmpty {
            return
        }
        if let apiResponse = try? decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        ) {
            try apiResponse.validateSuccess()
        }
    }

    func createStudyGroup(
        gisuId: Int,
        name: String,
        part: UMCPartType,
        memberIds: [Int],
        mentorIds: [Int]
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.createStudyGroup(
                body: StudyGroupCreateRequestDTO(
                    gisuId: gisuId,
                    name: name,
                    part: part.apiValue,
                    memberIds: memberIds,
                    mentorIds: mentorIds
                )
            )
        )

        if response.data.isEmpty {
            return
        }

        if let apiResponse = try? decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        ) {
            try apiResponse.validateSuccess()
            return
        }

        if let apiResponse = try? decoder.decode(
            APIResponse<StudyGroupDetailDTO>.self,
            from: response.data
        ),
           let _ = try? apiResponse.unwrap() {
            return
        }
    }

    func createStudyGroupSchedule(
        name: String,
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool,
        locationName: String,
        latitude: Double,
        longitude: Double,
        description: String,
        studyGroupId: Int,
        gisuId: Int,
        requiresApproval: Bool
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.createStudyGroupSchedule(
                body: StudyGroupScheduleCreateRequestDTO(
                    name: name,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    isAllDay: isAllDay,
                    locationName: locationName,
                    latitude: latitude,
                    longitude: longitude,
                    description: description,
                    tags: ["STUDY"],
                    studyGroupId: studyGroupId,
                    gisuId: gisuId,
                    requiresApproval: requiresApproval
                )
            )
        )

        let apiResponse = try decoder.decode(
            APIResponse<String>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    func updateStudyGroup(
        groupId: Int,
        name: String
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.updateStudyGroup(
                groupId: groupId,
                body: StudyGroupUpdateRequestDTO(name: name)
            )
        )

        if response.data.isEmpty {
            return
        }

        do {
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let repositoryError as RepositoryError {
            throw repositoryError
        } catch {
            throw RepositoryError.decodingError(
                detail: error.localizedDescription
            )
        }
    }

    func addStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.addStudyGroupMember(groupId: groupId, memberId: memberId)
        )
        try validateEmptyResultIfNeeded(response: response)
    }

    func removeStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.removeStudyGroupMember(groupId: groupId, memberId: memberId)
        )
        try validateEmptyResultIfNeeded(response: response)
    }

    func addStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.addStudyGroupMentor(groupId: groupId, mentorId: mentorId)
        )
        try validateEmptyResultIfNeeded(response: response)
    }

    func removeStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.removeStudyGroupMentor(groupId: groupId, mentorId: mentorId)
        )
        try validateEmptyResultIfNeeded(response: response)
    }

    private func validateEmptyResultIfNeeded(response: Response) throws {
        if response.data.isEmpty {
            return
        }

        do {
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let repositoryError as RepositoryError {
            throw repositoryError
        } catch {
            throw RepositoryError.decodingError(
                detail: error.localizedDescription
            )
        }
    }

    func deleteStudyGroup(
        groupId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.deleteStudyGroup(
                groupId: groupId
            )
        )

        if response.data.isEmpty {
            return
        }

        if let apiResponse = try? decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        ) {
            try apiResponse.validateSuccess()
        }
    }

    // MARK: - Private Helper

    /// 제출 현황 조회용 접근 가능 스터디 그룹 ID 목록을 역할별 정책에 맞춰 수집합니다.
    ///
    /// - 회장/부회장: `/study-groups/names` 우선
    /// - 그 외: `/study-groups` 우선
    private func fetchAccessibleStudyGroupIDsForSubmission() async throws -> [Int] {
        if isSchoolCoreRole,
           let groupsByNames = try? await fetchStudyGroupsByNames() {
            let ids = studyGroupIDs(from: groupsByNames)
            if !ids.isEmpty {
                return ids
            }
        }

        if let myGroups = try await fetchMyStudyGroups() {
            let ids = studyGroupIDs(from: myGroups)
            if !ids.isEmpty {
                return ids
            }
        }

        if let groupsByNames = try? await fetchStudyGroupsByNames() {
            let ids = studyGroupIDs(from: groupsByNames)
            if !ids.isEmpty {
                return ids
            }
        }

        return []
    }

    /// 그룹 목록에서 유효한 서버 그룹 ID만 추출하고 중복을 제거합니다.
    private func studyGroupIDs(from groups: [StudyGroupItem]) -> [Int] {
        var orderedUniqueIDs: [Int] = []
        var seen: Set<Int> = []

        for group in groups where group != .all {
            guard let groupID = Int(group.serverID), groupID > 0 else { continue }
            if seen.insert(groupID).inserted {
                orderedUniqueIDs.append(groupID)
            }
        }

        return orderedUniqueIDs
    }

    /// 여러 그룹 조회 결과를 순서를 유지한 채 중복 제거합니다.
    private func deduplicatedMembersPreservingOrder(
        _ members: [StudyMemberItem]
    ) -> [StudyMemberItem] {
        var seenKeys: Set<String> = []
        var deduplicated: [StudyMemberItem] = []

        for member in members {
            let key: String
            if let challengerWorkbookId = member.challengerWorkbookId {
                key = "workbook:\(challengerWorkbookId)"
            } else {
                key = "member:\(member.serverID):\(member.studyTopic)"
            }

            if seenKeys.insert(key).inserted {
                deduplicated.append(member)
            }
        }

        return deduplicated
    }

    private func fetchMembersByGroup(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem] {
        var cursor: Int? = nil
        var hasNext = true
        var members: [StudyMemberItem] = []

        while hasNext {
            let response = try await adapter.request(
                StudyRouter.getWorkbookSubmissions(
                    weekNo: week,
                    studyGroupId: studyGroupId,
                    cursor: cursor,
                    size: 100
                )
            )
            let page: WorkbookSubmissionPageDTO
            if let apiResponse = try? decoder.decode(
                APIResponse<WorkbookSubmissionPageDTO>.self,
                from: response.data
            ),
               let wrapped = try? apiResponse.unwrap() {
                page = wrapped
            } else {
                page = try decoder.decode(
                    WorkbookSubmissionPageDTO.self,
                    from: response.data
                )
            }

            members.append(contentsOf: page.content.map {
                $0.toDomain(week: week, studyGroupId: studyGroupId) })
            hasNext = page.hasNext
            cursor = page.nextCursor
        }
        return members
    }

    /// 회장단(교내 회장/부회장) 권한 여부
    private var isSchoolCoreRole: Bool {
        let defaults = UserDefaults.standard

        if let roleRawValues = defaults.stringArray(
            forKey: AppStorageKey.memberRoles
        ), !roleRawValues.isEmpty {
            let roles = roleRawValues.compactMap {
                ManagementTeam(rawValue: $0)
            }
            if roles.contains(.schoolPresident)
                || roles.contains(.schoolVicePresident) {
                return true
            }
        }

        let roleRawValue = defaults.string(
            forKey: AppStorageKey.memberRole
        ) ?? ""
        guard let role = ManagementTeam(rawValue: roleRawValue) else {
            return false
        }
        return role == .schoolPresident
            || role == .schoolVicePresident
    }

    /// 교내 회장단 전용 전체 그룹 목록 조회 (`/study-groups/names`)
    private func fetchStudyGroupsByNames() async throws -> [StudyGroupItem]? {
        let response = try await adapter.request(StudyRouter.getStudyGroupNames)

        // 서버별 응답 포맷 차이를 흡수합니다.
        if let apiResponse = try? decoder.decode(
            APIResponse<StudyGroupNamesDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped.toDomain()
        }

        if let plain = try? decoder.decode(
            StudyGroupNamesDTO.self,
            from: response.data
        ) {
            return plain.toDomain()
        }

        return nil
    }

    /// 회장단 외 사용자 전용 그룹 목록 조회 (`/study-groups`, cursor 기반)
    private func fetchMyStudyGroups() async throws -> [StudyGroupItem]? {
        var cursor: Int? = nil
        var hasNext = true
        var aggregated: [StudyGroupNameItemDTO] = []

        while hasNext {
            guard let page = try await fetchMyStudyGroupsPage(
                cursor: cursor,
                size: Constants.myStudyGroupsPageSize
            ) else {
                return nil
            }

            aggregated.append(contentsOf: page.studyGroups)
            hasNext = page.hasNext
            cursor = page.nextCursor
            if hasNext && cursor == nil {
                break
            }
        }

        guard !aggregated.isEmpty else {
            return [.all]
        }

        var deduplicatedByGroupID: [Int: StudyGroupNameItemDTO] = [:]
        aggregated.forEach { item in
            deduplicatedByGroupID[item.groupId] = item
        }

        let sortedItems = deduplicatedByGroupID.values.sorted { lhs, rhs in
            lhs.groupId < rhs.groupId
        }

        return [.all] + sortedItems.map {
            toStudyGroupItem($0)
        }
    }

    /// 회장단 외 사용자 전용 그룹 목록 단일 페이지 조회 (`/study-groups`, cursor 기반)
    private func fetchMyStudyGroupsPage(
        cursor: Int?,
        size: Int
    ) async throws -> MyStudyGroupsPageDTO? {
        let response = try await adapter.request(
            StudyRouter.getMyStudyGroups(
                cursor: cursor,
                size: size
            )
        )

        if let apiResponse = try? decoder.decode(
            APIResponse<MyStudyGroupsPageDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped
        }

        if let plain = try? decoder.decode(
            MyStudyGroupsPageDTO.self,
            from: response.data
        ) {
            return plain
        }

        return nil
    }

    /// 스터디 그룹 목록 페이지를 역할에 맞게 조회합니다.
    /// - Parameters:
    ///   - cursor: 페이지 커서 (첫 페이지 nil)
    ///   - size: 페이지 크기
    /// - Returns: 그룹 목록 페이지
    private func fetchStudyGroupItemsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupItemsPage {
        if isSchoolCoreRole {
            guard cursor == nil else {
                return StudyGroupItemsPage(
                    groups: [],
                    hasNext: false,
                    nextCursor: nil
                )
            }

            if let groupsByNames = try? await fetchStudyGroupsByNames() {
                let groups = groupsByNames.filter { $0 != .all }
                return StudyGroupItemsPage(
                    groups: groups,
                    hasNext: false,
                    nextCursor: nil
                )
            }

            if let myGroupsPage = try await fetchMyStudyGroupsPage(
                cursor: nil,
                size: size
            ) {
                return StudyGroupItemsPage(
                    groups: myGroupsPage.studyGroups.map(toStudyGroupItem),
                    hasNext: myGroupsPage.hasNext,
                    nextCursor: myGroupsPage.nextCursor
                )
            }

            return StudyGroupItemsPage(
                groups: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        if let myGroupsPage = try await fetchMyStudyGroupsPage(
            cursor: cursor,
            size: size
        ) {
            let myGroups = myGroupsPage.studyGroups.map(toStudyGroupItem)

            // 멀티 역할 사용자에서 role 캐시가 단일값으로 저장된 경우 보정
            // (`/study-groups`가 비어있고 `/study-groups/names`는 조회 가능한 케이스)
            if myGroups.isEmpty, cursor == nil,
               let groupsByNames = try? await fetchStudyGroupsByNames(),
               groupsByNames.contains(where: { $0 != .all }) {
                return StudyGroupItemsPage(
                    groups: groupsByNames.filter { $0 != .all },
                    hasNext: false,
                    nextCursor: nil
                )
            }

            return StudyGroupItemsPage(
                groups: myGroups,
                hasNext: myGroupsPage.hasNext,
                nextCursor: myGroupsPage.nextCursor
            )
        }

        if cursor == nil,
           let groupsByNames = try? await fetchStudyGroupsByNames(),
           groupsByNames.contains(where: { $0 != .all }) {
            return StudyGroupItemsPage(
                groups: groupsByNames.filter { $0 != .all },
                hasNext: false,
                nextCursor: nil
            )
        }

        return StudyGroupItemsPage(
            groups: [],
            hasNext: false,
            nextCursor: nil
        )
    }

    /// 단일 그룹 목록 항목 DTO를 도메인 모델로 변환합니다.
    private func toStudyGroupItem(_ dto: StudyGroupNameItemDTO) -> StudyGroupItem {
        StudyGroupItem(
            serverID: String(dto.groupId),
            name: dto.name,
            iconName: "person.2.fill",
            part: nil
        )
    }

    /// 그룹 목록에 대한 상세 DTO를 개별 조회합니다.
    private func fetchStudyGroupDetailDTOs(
        groups: [StudyGroupItem]
    ) async -> [(groupName: String, dto: StudyGroupDetailDTO)] {
        guard !groups.isEmpty else {
            return []
        }

        var detailDTOs: [(groupName: String, dto: StudyGroupDetailDTO)] = []
        for group in groups {
            guard let groupId = Int(group.serverID) else { continue }

            do {
                let response = try await adapter.request(
                    StudyRouter.getStudyGroupDetail(groupId: groupId)
                )

                let dto: StudyGroupDetailDTO
                if let apiResponse = try? decoder.decode(
                    APIResponse<StudyGroupDetailDTO>.self,
                    from: response.data
                ),
                   let wrapped = try? apiResponse.unwrap() {
                    dto = wrapped
                } else {
                    dto = try decoder.decode(
                        StudyGroupDetailDTO.self,
                        from: response.data
                    )
                }

                detailDTOs.append((groupName: group.name, dto: dto))
            } catch {
                continue
            }
        }

        return detailDTOs
    }

    /// 멤버별 베스트 워크북 점수 조회 (`/member/profile/{memberId}`)
    private func fetchBestWorkbookPoints(
        memberIDs: [Int]
    ) async -> [Int: Int] {
        var result: [Int: Int] = [:]

        await withTaskGroup(of: (Int, Int)?.self) { group in
            for memberID in Set(memberIDs) {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let point = await self.fetchBestWorkbookPoint(memberID: memberID)
                    return (memberID, point)
                }
            }

            for await item in group {
                guard let item else { continue }
                result[item.0] = item.1
            }
        }

        return result
    }

    /// 단일 멤버 베스트 워크북 점수 조회
    private func fetchBestWorkbookPoint(memberID: Int) async -> Int {
        do {
            let response = try await adapter.request(
                StudyRouter.getMemberProfile(memberId: memberID)
            )

            if let apiResponse = try? decoder.decode(
                APIResponse<MemberProfileBestWorkbookDTO>.self,
                from: response.data
            ),
               let wrapped = try? apiResponse.unwrap() {
                return wrapped.bestWorkbookDisplayPoint
            }

            if let plain = try? decoder.decode(
                MemberProfileBestWorkbookDTO.self,
                from: response.data
            ) {
                return plain.bestWorkbookDisplayPoint
            }
        } catch {
            // 포인트 조회 실패는 그룹 상세 표시를 막지 않도록 0점 처리
        }

        return 0
    }

    /// 멤버 프로필을 조회하여 챌린저 레코드 정보를 반환합니다.
    private func fetchMemberManagementProfile(
        memberId: Int
    ) async throws -> MemberManagementProfileDTO {
        let response = try await adapter.request(
            StudyRouter.getMemberProfile(memberId: memberId)
        )

        if let apiResponse = try? decoder.decode(
            APIResponse<MemberManagementProfileDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped
        }

        return try decoder.decode(
            MemberManagementProfileDTO.self,
            from: response.data
        )
    }

    /// UserDefaults에 저장된 담당 파트를 API 요청에 사용할 값으로 변환합니다.
    ///
    /// 알 수 없는 파트 값은 "IOS"로 fallback 처리합니다.
    private var resolvedPartAPIValue: String {
        let defaults = UserDefaults.standard
        let storedPart = defaults.string(forKey: AppStorageKey.responsiblePart) ?? "IOS"
        switch storedPart.uppercased() {
        case "PLAN", "DESIGN", "WEB", "ANDROID", "IOS", "NODEJS", "SPRINGBOOT":
            return storedPart.uppercased()
        default:
            return "IOS"
        }
    }

    /// UserDefaults에 저장된 현재 기수 ID를 반환합니다.
    private var preferredGisuId: Int? {
        let value = UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
        return value > 0 ? value : nil
    }

}

