//
//  MemberRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 2/24/26.
//

import Foundation
import Moya

/// 운영진 멤버 관리 Repository 실제 구현체
final class MemberRepository: MemberRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder
    private let studyRepository: StudyRepositoryProtocol

    // MARK: - Init

    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder(),
        studyRepository: StudyRepositoryProtocol
    ) {
        self.adapter = adapter
        self.decoder = decoder
        self.studyRepository = studyRepository
    }

    private var currentMemberID: Int {
        AppStorageKey.legacyMemberIdInt()
    }

    // MARK: - Function

    /// 학교 단위 멤버 전체 목록을 조회합니다.
    ///
    /// 오프셋 기반 API 우선 시도 후, 미지원 환경에서는 스터디 그룹 기반 레거시 경로로 폴백합니다.
    /// 각 멤버의 프로필 및 포인트 이력을 병렬 조회하여 `MemberManagementItem` 목록으로 반환합니다.
    ///
    /// - Returns: 파트 및 이름순 정렬된 멤버 관리 항목 배열
    /// - Throws: 네트워크 오류 또는 디코딩 오류
    func fetchMembers() async throws -> [MemberManagementItem] {
        let descriptors = try await fetchMemberDescriptors()
        guard !descriptors.isEmpty else {
            return []
        }

        let profileByMemberID = await fetchMemberProfiles(
            memberIDs: descriptors.map(\.memberId)
        )

        let preferredGisuID = resolvedGisuID
        let members = descriptors.map { descriptor in
            let profile = profileByMemberID[descriptor.memberId]
            let record = profile.flatMap {
                resolveRecord(
                    from: $0,
                    memberId: descriptor.memberId,
                    preferredGisuId: preferredGisuID
                )
            }
            let allPoints = record?.resolvedPoints ?? []

            let penaltyPoints = allPoints.filter {
                let typeStr = $0.pointType.uppercased()
                let resolved = ChallengerPointType(rawValue: typeStr)
                return resolved == nil || !(resolved!.isReward)
            }
            let rewardPointsList = allPoints.filter {
                let typeStr = $0.pointType.uppercased()
                let resolved = ChallengerPointType(rawValue: typeStr)
                return resolved?.isReward == true
            }

            let totalPenalty: Double
            let penaltyHistories: [OperatorMemberPenaltyHistory]

            if penaltyPoints.isEmpty {
                totalPenalty = descriptor.fallbackPenalty
                penaltyHistories = []
            } else {
                totalPenalty = penaltyPoints.reduce(0) { $0 + abs($1.point) }
                penaltyHistories = makePenaltyHistories(from: penaltyPoints)
            }

            let totalReward = rewardPointsList.reduce(0) { $0 + abs($1.point) }

            return MemberManagementItem(
                memberID: descriptor.memberId,
                challengerID: resolvedChallengerID(
                    descriptor: descriptor,
                    record: record
                ),
                profile: profile?.profileImageLink ?? descriptor.profileImageURL,
                name: profile?.name.nonEmpty ?? descriptor.name,
                nickname: profile?.nickname.nonEmpty ?? descriptor.name,
                generation: allGenerationsText(
                    from: profile,
                    fallback: descriptor.generation
                ),
                school: profile?.schoolName.nonEmpty ?? descriptor.schoolName,
                position: descriptor.position,
                part: descriptor.part,
                penalty: totalPenalty,
                rewardPoints: totalReward,
                badge: false,
                managementTeam: resolvedManagementTeam(
                    profile: profile,
                    record: record,
                    fallback: descriptor.managementTeam
                ),
                attendanceRecords: [],
                penaltyHistory: penaltyHistories,
                canViewPenaltyHistory: descriptor.memberId == currentMemberID
            )
        }

        return members.sorted { lhs, rhs in
            if lhs.part.sortOrder == rhs.part.sortOrder {
                return lhs.name < rhs.name
            }
            return lhs.part.sortOrder < rhs.part.sortOrder
        }
    }

    /// 챌린저에게 포인트를 부여합니다.
    func grantPoint(
        challengerId: Int,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.createChallengerPoint(
                challengerId: challengerId,
                body: ChallengerPointCreateRequestDTO(
                    pointType: pointType,
                    pointValue: pointValue,
                    description: description
                )
            )
        )

        if response.data.isEmpty {
            return
        }

        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 챌린저 포인트를 삭제합니다.
    func deletePoint(
        challengerPointId: Int
    ) async throws {
        let response = try await adapter.request(
            StudyRouter.deleteChallengerPoint(
                challengerPointId: challengerPointId
            )
        )

        if response.data.isEmpty {
            return
        }

        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 챌린저 상세에서 전체 포인트 히스토리를 조회합니다.
    func fetchPointHistory(
        challengerId: Int
    ) async throws -> [OperatorMemberPenaltyHistory] {
        let response = try await adapter.request(
            MyPageRouter.getChallengerProfile(challengerId: challengerId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<ChallengerMemberDTO>.self,
            from: response.data
        )
        let challenger = try apiResponse.unwrap()

        return challenger.challengerPoints
            .filter { $0.pointType != .warning }
            .map { point in
                let resolvedType = ChallengerPointType(rawValue: point.pointType.rawValue) ?? .out
                return OperatorMemberPenaltyHistory(
                    challengerPointId: point.id > 0 ? point.id : nil,
                    date: ServerDateTimeConverter.parseUTCDateTimeOrTime(point.createdAt)
                        ?? Date(),
                    reason: point.description.nonEmpty ?? resolvedType.displayName,
                    penaltyScore: abs(point.point),
                    pointType: resolvedType
                )
            }
            .sorted { $0.date > $1.date }
    }

    func fetchAllGenerations(memberId: Int) async throws -> String {
        let profile = try await fetchMemberProfile(memberId: memberId)
        return allGenerationsText(from: profile, fallback: "")
    }

    /// V2 일정 출석 현황에서 특정 멤버의 출석 이력을 조회합니다.
    ///
    /// NOTE: [#690] 전체 일정 응답에서 클라이언트 필터링. 데이터 규모가 커지면 페이지네이션 또는 백엔드 멤버 필터 도입 검토.
    func fetchAttendanceRecords(memberId: Int) async throws -> [MemberAttendanceRecord] {
        guard memberId > 0 else { return [] }

        let response = try await adapter.request(
            ScheduleV2Router.getAttendanceList(query: AttendanceListQuery(from: nil, to: nil, attendanceStatus: nil))
        )
        let apiResponse = try decoder.decode(
            APIResponse<[ScheduleAttendanceInfoDTO]>.self,
            from: response.data
        )
        let schedules = (try? apiResponse.unwrap()) ?? []

        let sorted = schedules.sorted {
            ($0.startsAt) < ($1.startsAt)
        }

        return sorted.enumerated().compactMap { index, schedule in
            guard let participant = schedule.participants.first(where: { $0.memberId == memberId }) else {
                return nil
            }
            let rawStatus = participant.attendanceStatus ?? "PENDING"
            return MemberAttendanceRecord(
                sessionTitle: schedule.name,
                week: index + 1,
                status: AttendanceStatus(serverStatus: rawStatus)
            )
        }
    }

    func fetchGenerationPointSummaries(
        memberId: Int
    ) async throws -> [GenerationPointSummary] {
        let profile = try await fetchMemberProfile(memberId: memberId)
        let records = profile.challengerRecords.filter {
            $0.memberId == memberId || $0.memberId == 0
        }
        guard !records.isEmpty else { return [] }

        return await withTaskGroup(
            of: GenerationPointSummary?.self
        ) { group in
            for record in records where record.gisu > 0 {
                group.addTask { @MainActor [adapter, decoder] in
                    guard let response = try? await adapter.request(
                        MyPageRouter.getChallengerProfile(
                            challengerId: record.challengerId
                        )
                    ),
                    let apiResponse = try? decoder.decode(
                        APIResponse<ChallengerMemberDTO>.self,
                        from: response.data
                    ),
                    let challenger = try? apiResponse.unwrap() else {
                        return GenerationPointSummary(
                            gisu: record.gisu, reward: 0, penalty: 0
                        )
                    }

                    let reward = challenger.challengerPoints
                        .filter {
                            let resolved = ChallengerPointType(
                                rawValue: $0.pointType.rawValue
                            )
                            return resolved?.isReward == true
                        }
                        .reduce(0.0) { $0 + abs($1.point) }
                    let penalty = challenger.challengerPoints
                        .filter {
                            let resolved = ChallengerPointType(
                                rawValue: $0.pointType.rawValue
                            )
                            return resolved == nil || !(resolved!.isReward)
                        }
                        .reduce(0.0) { $0 + abs($1.point) }

                    return GenerationPointSummary(
                        gisu: record.gisu,
                        reward: reward,
                        penalty: penalty
                    )
                }
            }

            var summaries: [GenerationPointSummary] = []
            for await summary in group {
                if let summary { summaries.append(summary) }
            }
            return summaries.sorted { $0.gisu < $1.gisu }
        }
    }
}

// MARK: - Private Helper

private extension MemberRepository {
    enum Constants {
        static let searchPageSize = 200
    }

    struct GroupMemberDescriptor: Hashable {
        let memberId: Int
        let challengerId: Int?
        let name: String
        let profileImageURL: String?
        let schoolName: String
        let generation: String
        let part: UMCPartType
        let position: String
        let managementTeam: ManagementTeam
        let fallbackPenalty: Double
    }

    func fetchMemberDescriptors() async throws -> [GroupMemberDescriptor] {
        if let schoolId = resolvedSchoolID {
            do {
                let descriptors = try await fetchMembersBySchoolOffset(
                    schoolId: schoolId
                )
                if !descriptors.isEmpty {
                    return descriptors
                }
            } catch let error as NetworkError where shouldFallbackToLegacyLookup(error) {
                // 학교 오프셋 API 미지원(404/405)일 때만 레거시 경로로 폴백합니다.
            } catch is DecodingError {
                // 응답 스키마가 다른 환경에서는 레거시 경로로 폴백합니다.
            }
        }

        let groups = try await fetchMemberBaseStudyGroups()
        return buildMemberDescriptors(from: groups)
    }

    func fetchMembersBySchoolOffset(
        schoolId: Int
    ) async throws -> [GroupMemberDescriptor] {
        var page: Int = 0
        var descriptorsByMemberId: [Int: GroupMemberDescriptor] = [:]

        while true {
            let response = try await adapter.request(
                StudyRouter.searchChallengersOffset(
                    page: page,
                    size: Constants.searchPageSize,
                    schoolId: schoolId
                )
            )
            let searchResult = try decodeSearchOffsetResult(from: response.data)
            let pageResult = searchResult.page

            for item in pageResult.content {
                guard item.memberId > 0 else { continue }

                let part = UMCPartType(apiValue: item.part) ?? .pm
                let managementTeam = ManagementTeam.highestPriority(in: item.roleTypes)
                    ?? .challenger
                let generation = resolvedGeneration(
                    generation: item.generation,
                    gisu: item.gisu
                )

                descriptorsByMemberId[item.memberId] = GroupMemberDescriptor(
                    memberId: item.memberId,
                    challengerId: item.challengerId > 0 ? item.challengerId : nil,
                    name: item.name,
                    profileImageURL: item.profileImageLink,
                    schoolName: item.schoolName,
                    generation: generation,
                    part: part,
                    position: managementTeam.korean,
                    managementTeam: managementTeam,
                    fallbackPenalty: max(0, item.pointSum)
                )
            }

            guard pageResult.hasNext else {
                break
            }

            page += 1
        }

        return descriptorsByMemberId.values.sorted { $0.memberId < $1.memberId }
    }

    func decodeSearchOffsetResult(
        from data: Data
    ) throws -> ChallengerSearchOffsetResultDTO {
        if let apiResponse = try? decoder.decode(
            APIResponse<ChallengerSearchOffsetResultDTO>.self,
            from: data
        ) {
            return try apiResponse.unwrap()
        }

        return try decoder.decode(
            ChallengerSearchOffsetResultDTO.self,
            from: data
        )
    }

    func fetchMemberBaseStudyGroups() async throws -> [StudyGroupInfo] {
        let allGroups = try await fetchAllStudyGroupDetails()
        if !allGroups.isEmpty {
            return allGroups
        }
        return try await studyRepository.fetchStudyGroupDetails()
    }

    func fetchAllStudyGroupDetails() async throws -> [StudyGroupInfo] {
        guard let groupItems = try await fetchStudyGroupNames(),
              !groupItems.isEmpty else {
            return []
        }

        var result: [StudyGroupInfo] = []
        for groupItem in groupItems where groupItem.groupId > 0 {
            guard let detailDTO = try await fetchStudyGroupDetailDTO(
                groupId: groupItem.groupId
            ) else { continue }
            result.append(
                detailDTO.toDomain(defaultGroupName: groupItem.name)
            )
        }

        return result
    }

    func shouldFallbackToLegacyLookup(
        _ error: NetworkError
    ) -> Bool {
        guard case .requestFailed(let statusCode, _) = error else {
            return false
        }
        return statusCode == 404 || statusCode == 405
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupNameItemDTO]? {
        let response = try await adapter.request(
            StudyRouter.getStudyGroupNames
        )

        if let apiResponse = try? decoder.decode(
            APIResponse<StudyGroupNamesDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped.studyGroups
        }

        if let plain = try? decoder.decode(
            StudyGroupNamesDTO.self,
            from: response.data
        ) {
            return plain.studyGroups
        }

        return nil
    }

    func fetchStudyGroupDetailDTO(
        groupId: Int
    ) async throws -> StudyGroupDetailDTO? {
        let response = try await adapter.request(
            StudyRouter.getStudyGroupDetail(groupId: groupId)
        )

        if let apiResponse = try? decoder.decode(
            APIResponse<StudyGroupDetailDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped
        }

        if let plain = try? decoder.decode(
            StudyGroupDetailDTO.self,
            from: response.data
        ) {
            return plain
        }

        return nil
    }

    var resolvedGisuID: Int? {
        let gisuId = UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
        return gisuId > 0 ? gisuId : nil
    }

    var resolvedSchoolID: Int? {
        let schoolId = UserDefaults.standard.integer(forKey: AppStorageKey.schoolId)
        return schoolId > 0 ? schoolId : nil
    }

    func buildMemberDescriptors(
        from groups: [StudyGroupInfo]
    ) -> [GroupMemberDescriptor] {
        var descriptorByMemberId: [Int: GroupMemberDescriptor] = [:]

        groups.forEach { group in
            group.mentors.forEach { mentor in
                let mentorMemberId = mentor.memberID
                    ?? Int(mentor.serverID)
                    ?? 0
                guard mentorMemberId > 0 else { return }
                descriptorByMemberId[mentorMemberId] = GroupMemberDescriptor(
                    memberId: mentorMemberId,
                    challengerId: mentor.challengerID,
                    name: mentor.name,
                    profileImageURL: mentor.profileImageURL,
                    schoolName: mentor.university,
                    generation: "-",
                    part: group.part,
                    position: "Leader",
                    managementTeam: .schoolPartLeader,
                    fallbackPenalty: 0
                )
            }

            group.members.forEach { member in
                let memberId = member.memberID
                    ?? Int(member.serverID)
                    ?? 0
                guard memberId > 0 else { return }
                if descriptorByMemberId[memberId] == nil {
                    descriptorByMemberId[memberId] = GroupMemberDescriptor(
                        memberId: memberId,
                        challengerId: member.challengerID,
                        name: member.name,
                        profileImageURL: member.profileImageURL,
                        schoolName: member.university,
                        generation: "-",
                        part: group.part,
                        position: "Member",
                        managementTeam: .challenger,
                        fallbackPenalty: 0
                    )
                }
            }
        }

        return descriptorByMemberId.values.sorted { $0.memberId < $1.memberId }
    }

    func fetchMemberProfiles(
        memberIDs: [Int]
    ) async -> [Int: MemberManagementProfileDTO] {
        var result: [Int: MemberManagementProfileDTO] = [:]

        await withTaskGroup(of: (Int, MemberManagementProfileDTO?).self) { group in
            for memberID in Set(memberIDs) where memberID > 0 {
                group.addTask { [weak self] in
                    guard let self else { return (memberID, nil) }
                    let profile = try? await self.fetchMemberProfile(memberId: memberID)
                    return (memberID, profile)
                }
            }

            for await (memberID, profile) in group {
                guard let profile else { continue }
                result[memberID] = profile
            }
        }

        return result
    }

    func fetchMemberProfile(
        memberId: Int
    ) async throws -> MemberManagementProfileDTO {
        if memberId == currentMemberID, currentMemberID > 0 {
            let response = try await adapter.request(MyPageRouter.getMyProfile)
            let apiResponse = try decoder.decode(
                APIResponse<MyPageProfileResponseDTO>.self,
                from: response.data
            )
            return MemberManagementProfileDTO(myProfileDTO: try apiResponse.unwrap())
        }

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

    func resolveRecord(
        from profile: MemberManagementProfileDTO,
        memberId: Int,
        preferredGisuId: Int?
    ) -> MemberManagementChallengerRecordDTO? {
        let matchedMemberRecords = profile.challengerRecords.filter {
            $0.memberId == memberId
        }

        if let preferredGisuId {
            if let matched = matchedMemberRecords.first(where: {
                $0.gisuId == preferredGisuId
            }) {
                return matched
            }

            if let matched = profile.challengerRecords.first(where: {
                $0.gisuId == preferredGisuId
            }) {
                return matched
            }
        }

        return matchedMemberRecords.first ?? profile.challengerRecords.first
    }

    func generationText(
        from record: MemberManagementChallengerRecordDTO?,
        fallback: String
    ) -> String {
        guard let gisu = record?.gisu, gisu > 0 else {
            return fallback
        }
        return "\(gisu)기"
    }

    /// 프로필의 모든 challengerRecords에서 중복 없는 기수 목록을 반환합니다.
    func allGenerationsText(
        from profile: MemberManagementProfileDTO?,
        fallback: String
    ) -> String {
        guard let records = profile?.challengerRecords, !records.isEmpty else {
            return fallback
        }
        let uniqueGisu = Set(records.map(\.gisu)).filter { $0 > 0 }.sorted()
        guard !uniqueGisu.isEmpty else { return fallback }
        return uniqueGisu.map { "\($0)기" }.joined(separator: ", ")
    }

    func resolvedChallengerID(
        descriptor: GroupMemberDescriptor,
        record: MemberManagementChallengerRecordDTO?
    ) -> Int? {
        if let challengerId = record?.challengerId, challengerId > 0 {
            return challengerId
        }
        return descriptor.challengerId
    }

    func resolvedManagementTeam(
        profile: MemberManagementProfileDTO?,
        record: MemberManagementChallengerRecordDTO?,
        fallback: ManagementTeam
    ) -> ManagementTeam {
        guard let profile else { return fallback }

        if let challengerId = record?.challengerId, challengerId > 0 {
            let matchedRoles = profile.roles
                .filter { $0.challengerId == nil || $0.challengerId == challengerId }
                .map(\.roleType)

            if let highestMatchedRole = ManagementTeam.highestPriority(in: matchedRoles) {
                return highestMatchedRole
            }
        }

        return ManagementTeam.highestPriority(in: profile.roles.map(\.roleType))
            ?? fallback
    }

    func resolvedGeneration(
        generation: Int?,
        gisu: Int?
    ) -> String {
        if let generation, generation > 0 {
            return "\(generation)기"
        }
        if let gisu, gisu > 0 {
            return "\(gisu)기"
        }
        return "-"
    }

    func makeGenerationPointSummaries(
        from profile: MemberManagementProfileDTO,
        memberId: Int
    ) -> [GenerationPointSummary] {
        let records = profile.challengerRecords.filter {
            $0.memberId == memberId || $0.memberId == 0
        }
        guard !records.isEmpty else { return [] }

        return records.compactMap { record in
            guard record.gisu > 0 else { return nil }
            let allPoints = record.resolvedPoints
            let reward = allPoints
                .filter {
                    let resolved = ChallengerPointType(
                        rawValue: $0.pointType.uppercased()
                    )
                    return resolved?.isReward == true
                }
                .reduce(0) { $0 + abs($1.point) }
            let penalty = allPoints
                .filter {
                    let resolved = ChallengerPointType(
                        rawValue: $0.pointType.uppercased()
                    )
                    return resolved == nil || !(resolved!.isReward)
                }
                .reduce(0) { $0 + abs($1.point) }
            return GenerationPointSummary(
                gisu: record.gisu,
                reward: reward,
                penalty: penalty
            )
        }
        .sorted { $0.gisu < $1.gisu }
    }

    func makePenaltyHistories(
        from points: [MemberManagementPointDTO]
    ) -> [OperatorMemberPenaltyHistory] {
        points.map { point in
            let resolvedType = ChallengerPointType(rawValue: point.pointType.uppercased()) ?? .out
            return OperatorMemberPenaltyHistory(
                challengerPointId: point.id > 0 ? point.id : nil,
                date: ServerDateTimeConverter.parseUTCDateTimeOrTime(point.createdAt)
                    ?? Date(),
                reason: point.description.nonEmpty ?? resolvedType.displayName,
                penaltyScore: abs(point.point),
                pointType: resolvedType
            )
        }
        .sorted { $0.date > $1.date }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
