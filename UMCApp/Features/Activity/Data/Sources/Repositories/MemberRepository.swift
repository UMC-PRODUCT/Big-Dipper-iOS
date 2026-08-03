//
//  MemberRepository.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import ActivityDomain
import CoreDomain
import CoreNetwork
import UMCFoundation
import Moya

/// 운영진 멤버 관리 Repository 구현체
///
/// ``MemberRepositoryProtocol`` 전체를 채택한다. 멤버 목록은 학교 단위 오프셋 검색
/// (``StudyRouter/searchChallengersOffset(query:)``)으로 수집한 뒤 멤버 프로필
/// (``StudyRouter/getMemberProfile(memberId:)``)로 상벌점·역할을 보강한다. 상벌점 부여/삭제는
/// 챌린저 포인트 엔드포인트로, 포인트 히스토리는 챌린저 프로필 엔드포인트
/// (``StudyRouter/getChallengerProfile(challengerId:)``)로 처리한다. 출석 이력은
/// ``AttendanceRouter/fetchAttendanceList(query:)`` 응답에서 멤버를 필터링한다.
///
/// - Note: 서버 식별자는 전 레이어 `String` 으로 통일된다(절대 규칙 #2). 멤버 조회에 필요한
///   `schoolId`·`currentMemberId`·`gisuId` 는 ``MemberContextProviding`` 에서 읽는다(신규
///   모듈에는 레거시 `AppStorageKey` 세션 저장소가 아직 없어 컨텍스트 제공자를 주입한다).
/// - Note: 레거시는 오프셋 검색 실패(404/405) 시 스터디 그룹 전수 열거로 폴백했으나, 본 모듈은
///   1차 경로(오프셋 검색)만 이식하고 폴백은 의도적으로 보류한다(후행 보강 대상). 따라서
///   `schoolId` 가 없으면 ``UMCFoundation/DomainError/custom(message:)`` 를 던진다 —
///   조용한 빈 배열 반환 대신 호출자에게 컨텍스트 부재를 명시적으로 알린다.
public final class MemberRepository: MemberRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any NetworkRequesting
    private let context: MemberContextProviding
    private let decoder: JSONDecoder

    // MARK: - Constants

    private enum Constants {
        /// 오프셋 검색 페이지당 항목 수.
        static let searchPageSize = 20
    }

    // MARK: - Init

    /// 운영(DI) 진입점.
    ///
    /// 인증 어댑터 ``CoreNetwork/MoyaNetworkAdapter`` 와 `UserDefaults` 기반 기본 컨텍스트
    /// 제공자를 사용한다. 테스트는 ``init(networkRequesting:context:decoder:)`` 에 가짜
    /// 구현을 주입한다.
    public convenience init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            networkRequesting: adapter,
            context: UserDefaultsMemberContextProvider(),
            decoder: decoder
        )
    }

    /// 의존성을 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(
        networkRequesting: any NetworkRequesting,
        context: MemberContextProviding,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.networkRequesting = networkRequesting
        self.context = context
        self.decoder = decoder
    }

    // MARK: - 멤버 목록

    public func fetchMembers() async throws -> [MemberManagementItem] {
        let schoolId = try requireSchoolId()
        let descriptors = try await fetchAllDescriptors(schoolId: schoolId)
        guard !descriptors.isEmpty else { return [] }
        return try await enrichDescriptors(descriptors)
    }

    public func fetchMembersPage(page: Int) async throws -> MemberPage {
        let schoolId = try requireSchoolId()
        let response = try await networkRequesting.request(
            StudyRouter.searchChallengersOffset(
                query: ChallengerSearchQuery(
                    page: page,
                    size: Constants.searchPageSize,
                    schoolId: schoolId
                )
            )
        )
        let result = try decoder.decode(
            APIResponse<ChallengerSearchOffsetResultDTO>.self,
            from: response.data
        ).unwrap()
        let pageResult = result.page
        let descriptors = makeDescriptors(from: pageResult.content)
        let members = try await enrichDescriptors(descriptors)
        return MemberPage(
            members: members,
            hasNext: pageResult.hasNext,
            currentPage: pageResult.page
        )
    }

    // MARK: - 챌린저 검색

    public func searchChallengers(
        keyword: String?,
        cursor: Int?,
        size: Int
    ) async throws -> ChallengerSearchPage {
        let response = try await networkRequesting.request(
            StudyRouter.searchChallengersCursor(
                query: ChallengerSearchCursorQuery(
                    cursor: cursor,
                    size: size,
                    keyword: keyword
                )
            )
        )
        let result = try decoder.decode(
            APIResponse<ChallengerSearchCursorResultDTO>.self,
            from: response.data
        ).unwrap()
        let page = result.cursor

        return ChallengerSearchPage(
            challengers: page.content.compactMap(makeChallengerInfo),
            hasNext: page.hasNext,
            nextCursor: page.nextCursor
        )
    }

    // MARK: - 상벌점 부여 / 삭제

    public func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        try await performVoidRequest(
            .createChallengerPoint(
                challengerId: challengerId,
                body: ChallengerPointCreateRequestDTO(
                    pointType: pointType,
                    pointValue: pointValue,
                    description: description
                )
            )
        )
    }

    public func deletePoint(challengerPointId: String) async throws {
        try await performVoidRequest(
            .deleteChallengerPoint(challengerPointId: challengerPointId)
        )
    }

    public func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        let response = try await networkRequesting.request(
            StudyRouter.getChallengerProfile(challengerId: challengerId)
        )
        let profile = try decoder.decode(
            APIResponse<ChallengerProfileDTO>.self,
            from: response.data
        ).unwrap()
        return makePenaltyHistories(from: profile.challengerPoints, includeWarning: false)
    }

    // MARK: - 멤버 상세

    public func fetchAllGenerations(memberId: String) async throws -> String {
        let profile = try await fetchMemberProfile(memberId: memberId)
        return allGenerationsText(from: profile, fallback: "")
    }

    /// 멤버의 기수별 상벌점 요약을 조회합니다.
    ///
    /// - Note: 레거시는 기수별 챌린저 ID 마다 MyPage 챌린저 프로필을 병렬로 조회했지만, 본 모듈은
    ///   단일 멤버 프로필(`challengerRecords[].resolvedPoints`)에서 요약을 뽑습니다 — MyPage
    ///   모듈에 기대지 않고 같은 데이터를 씁니다.
    public func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        let profile = try await fetchMemberProfile(memberId: memberId)
        return makeGenerationPointSummaries(from: profile, memberId: memberId)
    }

    /// 일정 출석 현황에서 특정 멤버의 출석 이력을 조회합니다.
    ///
    /// - Note: 전체 일정 응답에서 클라이언트 필터링합니다(레거시 동일). 데이터 규모가 커지면
    ///   페이지네이션 또는 백엔드 멤버 필터 도입을 검토합니다.
    public func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        guard !memberId.isEmpty else { return [] }

        let response = try await networkRequesting.request(
            AttendanceRouter.fetchAttendanceList(
                query: AttendanceListQuery(from: nil, to: nil, attendanceStatus: nil)
            )
        )
        let schedules = try decoder.decode(
            APIResponse<[ScheduleAttendanceInfoDTO]>.self,
            from: response.data
        ).unwrap()

        let sorted = schedules.sorted { $0.startsAt < $1.startsAt }
        return sorted.enumerated().compactMap { index, schedule in
            guard let participant = schedule.participants.first(where: {
                $0.memberId == memberId
            }) else {
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
}

// MARK: - Private Helper

private extension MemberRepository {

    /// 오프셋 검색 결과 + 프로필 보강에 사용하는 중간 표현.
    struct MemberDescriptor: Hashable {
        let memberId: String
        let challengerId: String?
        let name: String
        let nickname: String
        let profileImageURL: String?
        let schoolName: String
        let generation: String
        let part: UMCPartType
        let position: String
        let managementTeam: ManagementTeam
        let fallbackPenalty: Double
    }

    /// 멤버 조회의 전제 조건인 `schoolId` 를 반환하거나, 없으면 도메인 에러를 던집니다.
    func requireSchoolId() throws -> String {
        guard let schoolId = context.schoolId, !schoolId.isEmpty else {
            throw DomainError.custom(message: "학교 정보가 없어 멤버 목록을 조회할 수 없습니다.")
        }
        return schoolId
    }

    /// 오프셋 검색을 `hasNext` 가 끝날 때까지 순회하여 멤버 디스크립터를 수집합니다.
    func fetchAllDescriptors(schoolId: String) async throws -> [MemberDescriptor] {
        var page = 0
        var descriptorsByMemberId: [String: MemberDescriptor] = [:]

        while true {
            let response = try await networkRequesting.request(
                StudyRouter.searchChallengersOffset(
                    query: ChallengerSearchQuery(
                        page: page,
                        size: Constants.searchPageSize,
                        schoolId: schoolId
                    )
                )
            )
            let result = try decoder.decode(
                APIResponse<ChallengerSearchOffsetResultDTO>.self,
                from: response.data
            ).unwrap()
            let pageResult = result.page

            // 빈 페이지는 더 수집할 항목이 없다는 신호다. `hasNext` 가 true 로 와도 여기서
            // 중단해 무한 루프를 막는다(offset 페이지네이션의 진행 보장 가드 —
            // ``StudyRepository`` 의 커서 누락 가드와 동일한 의도).
            guard !pageResult.content.isEmpty else { break }

            for descriptor in makeDescriptors(from: pageResult.content) {
                descriptorsByMemberId[descriptor.memberId] = descriptor
            }

            guard pageResult.hasNext else { break }
            page += 1
        }

        return descriptorsByMemberId.values.sorted { $0.memberId < $1.memberId }
    }

    func makeDescriptors(
        from items: [ChallengerSearchOffsetItemDTO]
    ) -> [MemberDescriptor] {
        items.compactMap { item in
            guard !item.memberId.isEmpty else { return nil }
            let part = UMCPartType(apiValue: item.part) ?? .pm
            let managementTeam = ManagementTeam.highestPriority(in: item.roleTypes)
                ?? .challenger
            let generation = resolvedGeneration(
                generation: item.generation,
                gisu: item.gisu
            )
            return MemberDescriptor(
                memberId: item.memberId,
                challengerId: item.challengerId.nonEmpty,
                name: item.name,
                nickname: item.nickname,
                profileImageURL: item.profileImageURL,
                schoolName: item.schoolName,
                generation: generation,
                part: part,
                position: managementTeam.korean,
                managementTeam: managementTeam,
                fallbackPenalty: max(0, item.pointSum)
            )
        }
    }

    /// 검색 항목을 Core canonical ``CoreDomain/ChallengerInfo`` 로 매핑합니다.
    ///
    /// `memberId` 가 비면 선택 키(`selectionKey`)를 만들 수 없고 그룹 추가 API 도 호출할 수
    /// 없으므로 그 항목은 제외합니다(`compactMap`).
    ///
    /// - Note: `gen` 은 `"9기"` 같은 표시 문구가 아니라 **기수 번호 문자열**(`"9"`)입니다.
    ///   `StudyRepository.resolveChallengerId(memberId:preferredGeneration:)` 가 이 값을
    ///   `Int` 로 바꿔 챌린저 레코드의 `gisu` 와 비교하기 때문입니다. 기수를 알 수 없으면
    ///   빈 문자열을 둬 호출부가 "기수 미지정"으로 다루게 합니다.
    func makeChallengerInfo(
        from item: ChallengerSearchOffsetItemDTO
    ) -> ChallengerInfo? {
        guard !item.memberId.isEmpty else { return nil }

        return ChallengerInfo(
            memberId: item.memberId,
            challengerId: item.challengerId.nonEmpty,
            gen: gisuNumberText(generation: item.generation, gisu: item.gisu),
            name: item.name,
            nickname: item.nickname,
            schoolName: item.schoolName,
            profileImage: item.profileImageURL,
            part: UMCPartType(apiValue: item.part) ?? .pm
        )
    }

    /// 기수 번호를 문자열로 반환합니다 (알 수 없으면 빈 문자열).
    ///
    /// 서버는 같은 값을 `generation`·`gisu` 두 키로 내려주며(`gisu` 는 FE 이관용 별칭),
    /// 한쪽만 채워 오는 경우에 대비해 순서대로 확인합니다.
    func gisuNumberText(generation: Int?, gisu: Int?) -> String {
        if let generation, generation > 0 {
            return "\(generation)"
        }
        if let gisu, gisu > 0 {
            return "\(gisu)"
        }
        return ""
    }

    /// 각 디스크립터의 멤버 프로필을 조회해 상벌점·역할을 보강하고 정렬합니다.
    ///
    /// - Note: 레거시는 프로필을 병렬(`withTaskGroup`)로 조회했으나, 본 모듈은 순차 조회합니다.
    ///   테스트의 ``NetworkRequesting`` 가짜 구현이 FIFO 큐라 호출 순서가 결정론적이어야 하기
    ///   때문이며, 멤버 수가 크게 늘면 병렬화를 재검토합니다.
    /// - Note: 프로필 조회 실패는 전파합니다(`try await`). 레거시·`try?` 는 개별 실패를 흡수해
    ///   검색 디스크립터 값만으로 구성했지만, 그러면 인증 만료·서버·디코딩 실패가 전 멤버에 걸쳐도
    ///   목록을 폴백 데이터로 "성공"처럼 반환해 운영진이 잘못된 상벌점을 봅니다(silent failure).
    ///   비-2xx 는 ``NetworkRequesting`` 이 throw 하므로 전파해 호출자가 명시적 실패로 처리합니다
    ///   (`StudyRepository.resolveChallengerId` 와 동일 방침). 멤버별 부분 성공이 필요해지면
    ///   404 등 recoverable 상태만 선별 흡수하도록 후속 보강합니다.
    func enrichDescriptors(
        _ descriptors: [MemberDescriptor]
    ) async throws -> [MemberManagementItem] {
        let preferredGisuId = context.gisuId
        let currentMemberId = context.currentMemberId

        var members: [MemberManagementItem] = []
        members.reserveCapacity(descriptors.count)

        for descriptor in descriptors {
            let profile = try await fetchMemberProfile(memberId: descriptor.memberId)
            let record = resolveRecord(
                from: profile,
                memberId: descriptor.memberId,
                preferredGisuId: preferredGisuId
            )
            members.append(
                makeMemberItem(
                    descriptor: descriptor,
                    profile: profile,
                    record: record,
                    currentMemberId: currentMemberId
                )
            )
        }

        return members.sorted { lhs, rhs in
            if lhs.part.sortOrder == rhs.part.sortOrder {
                return lhs.name < rhs.name
            }
            return lhs.part.sortOrder < rhs.part.sortOrder
        }
    }

    func makeMemberItem(
        descriptor: MemberDescriptor,
        profile: MemberManagementProfileDTO?,
        record: MemberManagementChallengerRecordDTO?,
        currentMemberId: String?
    ) -> MemberManagementItem {
        let allPoints = record?.resolvedPoints ?? []
        let penaltyPoints = allPoints.filter { !isReward(pointType: $0.pointType) }
        let rewardPoints = allPoints.filter { isReward(pointType: $0.pointType) }

        let totalPenalty: Double
        let penaltyHistories: [OperatorMemberPenaltyHistory]
        if penaltyPoints.isEmpty {
            totalPenalty = descriptor.fallbackPenalty
            penaltyHistories = []
        } else {
            totalPenalty = penaltyPoints.reduce(0) { $0 + abs($1.point) }
            penaltyHistories = makePenaltyHistories(from: penaltyPoints, includeWarning: true)
        }
        let totalReward = rewardPoints.reduce(0) { $0 + abs($1.point) }

        return MemberManagementItem(
            memberID: descriptor.memberId,
            challengerID: resolvedChallengerID(descriptor: descriptor, record: record),
            profile: profile?.profileImageURL ?? descriptor.profileImageURL,
            name: profile?.name.nonEmpty ?? descriptor.name,
            nickname: profile?.nickname.nonEmpty ?? descriptor.nickname,
            generation: allGenerationsText(from: profile, fallback: descriptor.generation),
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
            canViewPenaltyHistory: descriptor.memberId == currentMemberId
        )
    }

    /// 멤버 프로필을 조회합니다.
    ///
    /// - Note: 레거시는 본인 프로필일 때 MyPage `getMyProfile` 를 사용했으나, 본 모듈은 MyPage
    ///   를 의존하지 않으므로 본인 포함 모든 멤버를 `getMemberProfile` 로 일관 조회합니다(같은
    ///   `/api/v1/member/profile/{memberId}` 데이터).
    func fetchMemberProfile(
        memberId: String
    ) async throws -> MemberManagementProfileDTO {
        let response = try await networkRequesting.request(
            StudyRouter.getMemberProfile(memberId: memberId)
        )
        return try decoder.decode(
            APIResponse<MemberManagementProfileDTO>.self,
            from: response.data
        ).unwrap()
    }

    func resolveRecord(
        from profile: MemberManagementProfileDTO,
        memberId: String,
        preferredGisuId: String?
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

    func resolvedChallengerID(
        descriptor: MemberDescriptor,
        record: MemberManagementChallengerRecordDTO?
    ) -> String? {
        if let challengerId = record?.challengerId, !challengerId.isEmpty {
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

        if let challengerId = record?.challengerId, !challengerId.isEmpty {
            let matchedRoles = profile.roles
                .filter { $0.challengerId == nil || $0.challengerId == challengerId }
                .map(\.roleType)

            if let highest = ManagementTeam.highestPriority(in: matchedRoles) {
                return highest
            }
        }

        return ManagementTeam.highestPriority(in: profile.roles.map(\.roleType))
            ?? fallback
    }

    func resolvedGeneration(generation: Int?, gisu: Int?) -> String {
        if let generation, generation > 0 {
            return "\(generation)기"
        }
        if let gisu, gisu > 0 {
            return "\(gisu)기"
        }
        return "-"
    }

    /// 프로필의 모든 `challengerRecords` 에서 중복 없는 기수 목록 텍스트를 반환합니다.
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

    func makeGenerationPointSummaries(
        from profile: MemberManagementProfileDTO,
        memberId: String
    ) -> [GenerationPointSummary] {
        let records = profile.challengerRecords.filter {
            $0.memberId == memberId || $0.memberId.isEmpty
        }
        guard !records.isEmpty else { return [] }

        return records.compactMap { record in
            guard record.gisu > 0 else { return nil }
            let allPoints = record.resolvedPoints
            let reward = allPoints
                .filter { isReward(pointType: $0.pointType) }
                .reduce(0) { $0 + abs($1.point) }
            let penalty = allPoints
                .filter { !isReward(pointType: $0.pointType) }
                .reduce(0) { $0 + abs($1.point) }
            return GenerationPointSummary(
                gisu: record.gisu,
                reward: reward,
                penalty: penalty
            )
        }
        .sorted { $0.gisu < $1.gisu }
    }

    /// 포인트 항목을 상벌점 히스토리로 매핑합니다.
    ///
    /// - Parameter includeWarning: `false` 면 `WARNING` 유형을 제외합니다(포인트 히스토리 조회).
    func makePenaltyHistories(
        from points: [MemberManagementPointDTO],
        includeWarning: Bool
    ) -> [OperatorMemberPenaltyHistory] {
        points
            .filter { point in
                guard !includeWarning else { return true }
                return ChallengerPointType(rawValue: point.pointType.uppercased()) != .warning
            }
            .map { point in
                let resolvedType = ChallengerPointType(
                    rawValue: point.pointType.uppercased()
                ) ?? .out
                return OperatorMemberPenaltyHistory(
                    challengerPointId: point.id.nonEmpty,
                    date: ServerDateTimeConverter.parseUTCDateTimeOrTime(point.createdAt)
                        ?? Date(),
                    reason: point.description.nonEmpty ?? resolvedType.displayName,
                    penaltyScore: abs(point.point),
                    pointType: resolvedType
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// 포인트 유형 문자열이 상점(보상)인지 판별합니다(미지의 유형은 벌점으로 간주).
    ///
    /// - Note: 분류는 ``UMCFoundation/ChallengerPointType/isReward``(유형의 기본 배점 부호)에
    ///   위임하므로, 레거시 호환으로 양수(1)인 `WARNING`/`OUT` 은 상점으로, 기본 배점 0 인
    ///   `CUSTOM` 은 벌점으로 분류됩니다(레거시 동일 동작). 일반 부여 흐름은
    ///   `availableTypes(for:)` 에서 `WARNING`/`OUT` 을 제외하므로 영향이 제한적입니다. 서버
    ///   `point` 부호 기반 정밀 분류는 contract 확정 후 별도 보강합니다.
    func isReward(pointType raw: String) -> Bool {
        ChallengerPointType(rawValue: raw.uppercased())?.isReward == true
    }

    /// 결과 본문이 없는 변경(부여/삭제) 요청의 공통 호출·검증.
    ///
    /// ``StudyRepository`` 의 동명 헬퍼와 동일한 계약: 빈 본문 2xx 는 성공으로 처리하고, 본문이
    /// 있으면 `APIResponse<EmptyResult>` 의 성공 여부만 검증한다.
    func performVoidRequest(_ target: StudyRouter) async throws {
        let response = try await networkRequesting.request(target)
        guard !response.data.isEmpty else { return }
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }
}

// MARK: - String + NonEmpty

private extension String {
    /// 빈 문자열이면 `nil`, 아니면 자기 자신.
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
