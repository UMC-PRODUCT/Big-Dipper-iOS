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
        let response: Moya.Response
        do {
            response = try await adapter.request(
                StudyRouter.getCurriculum(gisuId: gisuId, part: part, weekNo: weekNo)
            )
        } catch let error as NetworkError {
            if case .requestFailed(_, let data) = error,
               let data,
               let body = try? JSONDecoder().decode(APIResponse<EmptyResult>.self, from: data),
               body.code == "CURRICULUM-0001" {
                throw DomainError.curriculumNotRegistered
            }
            throw error
        }
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

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        guard let gisuId = preferredGisuId, gisuId > 0 else {
            throw DomainError.curriculumUnavailableForGeneration
        }
        let part = resolvedPartAPIValue
        let response = try await adapter.request(
            StudyRouter.getCurriculum(gisuId: gisuId, part: part, weekNo: nil)
        )
        let apiResponse = try decoder.decode(
            APIResponse<CurriculumDTO>.self,
            from: response.data
        )
        let dto = try apiResponse.unwrap()
        return dto.weeks
            .sorted { $0.weekNo < $1.weekNo }
            .map {
                WeeklyCurriculumOption(
                    weeklyCurriculumId: $0.weeklyCurriculumId,
                    weekNo: $0.weekNo,
                    title: $0.title
                )
            }
    }

    // MARK: - 운영진 스터디 관리

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

    func fetchStudyGroupDetail(groupId: Int) async throws -> StudyGroupInfo {
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
            dto = try decoder.decode(StudyGroupDetailDTO.self, from: response.data)
        }

        return dto.toDomain()
    }

    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.linkStudyGroupSchedule(
                body: StudyGroupScheduleCreateRequestDTO(
                    scheduleId: scheduleId,
                    studyGroupId: studyGroupId,
                    weeklyCurriculumId: weeklyCurriculumId
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

    /// 스터디 그룹 목록 페이지를 `/study-groups/managed` 로 조회합니다.
    /// - Parameters:
    ///   - cursor: 페이지 커서 (첫 페이지 nil)
    ///   - size: 페이지 크기
    /// - Returns: 그룹 목록 페이지
    private func fetchStudyGroupItemsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupItemsPage {
        guard let myGroupsPage = try await fetchMyStudyGroupsPage(
            cursor: cursor,
            size: size
        ) else {
            return StudyGroupItemsPage(
                groups: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return StudyGroupItemsPage(
            groups: myGroupsPage.studyGroups.map(toStudyGroupItem),
            hasNext: myGroupsPage.hasNext,
            nextCursor: myGroupsPage.nextCursor
        )
    }

    /// 로그인 사용자의 스터디 그룹 목록 페이지 단건 조회 (`/study-groups/managed`, cursor 기반)
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

    /// 단일 그룹 목록 항목 DTO를 도메인 모델로 변환합니다.
    private func toStudyGroupItem(_ dto: StudyGroupNameItemDTO) -> StudyGroupItem {
        StudyGroupItem(
            serverID: String(dto.groupId),
            name: dto.name,
            iconName: "person.2.fill"
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
