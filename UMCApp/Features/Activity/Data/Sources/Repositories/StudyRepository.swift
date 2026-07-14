//
//  StudyRepository.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/24/26.
//

import Foundation
import ActivityDomain
import CoreNetwork
import UMCFoundation
import Moya

/// 스터디 Repository 구현체
///
/// ``StudyRepositoryProtocol`` 전체를 채택한다. 조회 계열(커리큘럼/미션/주차 옵션, 운영진
/// 스터디 그룹 조회, 챌린저 ID 해석)과 운영진 스터디 그룹 CRUD·일정 연결을 모두 ``StudyRouter``
/// case 로 실구현한다. ``NetworkRequesting`` 으로 요청을 보낸 뒤 조회는 `APIResponse<DTO>` 를
/// 디코딩해 `toDomain()` 으로 매핑하고, 결과 없는 변경(CRUD/연결)은 `APIResponse<EmptyResult>`
/// 의 성공 여부만 검증한다.
///
/// - Note: 서버 식별자는 전 레이어 `String` 으로 통일된다. 커리큘럼 조회에 필요한 현재
///   기수·담당 파트는 ``StudyContextProviding`` 에서 읽는다(신규 모듈에는 레거시
///   `AppStorageKey` 세션 저장소가 아직 없어 컨텍스트 제공자를 주입한다).
public final class StudyRepository: StudyRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any NetworkRequesting
    private let context: StudyContextProviding
    private let decoder: JSONDecoder

    // MARK: - Constants

    private enum Constants {
        /// 운영진 스터디 그룹 전체 조회 시 페이지당 항목 수.
        static let studyGroupsPageSize = 100
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
            context: UserDefaultsStudyContextProvider(),
            decoder: decoder
        )
    }

    /// 의존성을 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(
        networkRequesting: any NetworkRequesting,
        context: StudyContextProviding,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.networkRequesting = networkRequesting
        self.context = context
        self.decoder = decoder
    }

    // MARK: - 커리큘럼 / 미션

    public func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        let curriculum = try await fetchCurriculum()
        return curriculum.dto.toCurriculumProgress(part: curriculum.part)
    }

    public func fetchMissions() async throws -> [MissionCardModel] {
        let curriculum = try await fetchCurriculum()
        let platform = UMCPartType(apiValue: curriculum.part)?.name ?? curriculum.part
        return curriculum.dto.toMissionCards(platform: platform)
    }

    /// 주차 커리큘럼 옵션을 조회한다.
    ///
    /// 전용 엔드포인트가 아직 없어 커리큘럼 개요(`getCurriculum`)의 주차 목록에서 파생한다.
    /// 주차 번호(`weekNo`)는 도메인 모델이 `String` 이므로 변환해 담는다.
    public func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        let curriculum = try await fetchCurriculum()
        return curriculum.dto.weeks
            .sorted { $0.weekNo < $1.weekNo }
            .map {
                WeeklyCurriculumOption(
                    weeklyCurriculumId: $0.weeklyCurriculumId,
                    weekNo: String($0.weekNo),
                    title: $0.title
                )
            }
    }

    // MARK: - 운영진 스터디 그룹 조회

    public func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        var allDetails: [StudyGroupInfo] = []
        var cursor: String?
        var hasNext = true

        while hasNext {
            let page = try await fetchStudyGroupDetailsPage(
                cursor: cursor,
                size: Constants.studyGroupsPageSize
            )
            allDetails.append(contentsOf: page.content)

            hasNext = page.hasNext
            cursor = page.nextCursor
            // 다음 페이지가 있다고 했으나 커서가 없으면 무한 루프 방지를 위해 중단한다.
            if hasNext && cursor == nil {
                break
            }
        }

        return allDetails
    }

    public func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        let response = try await networkRequesting.request(
            StudyRouter.getMyStudyGroups(
                query: MyStudyGroupsQuery(cursor: cursor, size: size)
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<MyStudyGroupsPageDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    public func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        let response = try await networkRequesting.request(
            StudyRouter.getStudyGroupDetail(groupId: groupId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<StudyGroupDetailDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    public func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        let response = try await networkRequesting.request(
            StudyRouter.getMemberProfile(memberId: memberId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<MemberProfileDTO>.self,
            from: response.data
        )
        let profile = try apiResponse.unwrap()

        let records = profile.challengerRecords.filter {
            $0.memberId == memberId && !$0.challengerId.isEmpty
        }

        // 기수는 String 으로 전달받아 숫자 비교 연산 시점에만 Int 로 변환한다.
        if let preferredGisu = preferredGeneration.flatMap(Int.init), preferredGisu > 0,
           let matched = records.first(where: { $0.gisu == preferredGisu }) {
            return matched.challengerId
        }

        if let preferredGisuId = context.gisuId,
           let matched = records.first(where: { $0.gisuId == preferredGisuId }) {
            return matched.challengerId
        }

        return records.first?.challengerId
    }

    // MARK: - 운영진 스터디 그룹 CRUD / 일정 연결

    public func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        let body = StudyGroupCreateRequestDTO(
            gisuId: try intIdentifier(gisuId, field: "gisuId"),
            name: name,
            part: part.apiValue,
            memberIds: try intIdentifiers(memberIds, field: "memberIds"),
            mentorIds: try intIdentifiers(mentorIds, field: "mentorIds")
        )
        try await performVoidRequest(.createStudyGroup(body: body))
    }

    public func updateStudyGroup(groupId: String, name: String) async throws {
        try await performVoidRequest(
            .updateStudyGroup(
                groupId: groupId,
                body: StudyGroupUpdateRequestDTO(name: name)
            )
        )
    }

    public func deleteStudyGroup(groupId: String) async throws {
        try await performVoidRequest(.deleteStudyGroup(groupId: groupId))
    }

    public func addStudyGroupMember(groupId: String, memberId: String) async throws {
        try await performVoidRequest(
            .addStudyGroupMember(groupId: groupId, memberId: memberId)
        )
    }

    public func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        try await performVoidRequest(
            .removeStudyGroupMember(groupId: groupId, memberId: memberId)
        )
    }

    public func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        try await performVoidRequest(
            .addStudyGroupMentor(groupId: groupId, mentorId: mentorId)
        )
    }

    public func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        try await performVoidRequest(
            .removeStudyGroupMentor(groupId: groupId, mentorId: mentorId)
        )
    }

    public func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        let body = StudyGroupScheduleCreateRequestDTO(
            scheduleId: try intIdentifier(scheduleId, field: "scheduleId"),
            studyGroupId: try intIdentifier(studyGroupId, field: "studyGroupId"),
            weeklyCurriculumId: try intIdentifier(
                weeklyCurriculumId, field: "weeklyCurriculumId"
            )
        )
        try await performVoidRequest(.linkStudyGroupSchedule(body: body))
    }
}

// MARK: - Private Helper

private extension StudyRepository {

    /// 커리큘럼 조회의 공통 단계: 컨텍스트에서 기수·파트를 읽어 ``StudyRouter/getCurriculum``
    /// 을 호출하고 ``CurriculumDTO`` 로 디코딩한다.
    ///
    /// 현재 운영 기수(`gisuId`)가 없으면 네트워크 호출 없이
    /// ``DomainError/curriculumUnavailableForGeneration`` 을 던진다.
    ///
    /// - Note: 레거시는 `CURRICULUM-0001`(커리큘럼 미등록) 본문을 별도 도메인 에러로
    ///   승격했으나, 신규 모듈에는 대응 case 가 아직 없어 서버 실패는 표준
    ///   ``RepositoryError/serverError(code:message:)`` 경로로 노출한다(도메인 vocabulary
    ///   추가 시 후속 보강).
    /// - Returns: 디코딩한 ``CurriculumDTO`` 와 조회에 사용한 파트 문자열
    func fetchCurriculum() async throws -> (dto: CurriculumDTO, part: String) {
        guard let gisuId = context.gisuId else {
            throw DomainError.curriculumUnavailableForGeneration
        }
        let part = context.part
        let response = try await networkRequesting.request(
            StudyRouter.getCurriculum(
                query: CurriculumOverviewQuery(gisuId: gisuId, part: part, weekNo: nil)
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<CurriculumDTO>.self,
            from: response.data
        )
        return (try apiResponse.unwrap(), part)
    }

    /// 결과 본문이 없는 변경(CRUD/연결) 요청의 공통 호출·검증.
    ///
    /// 비-2xx 는 네트워크 계층(``NetworkRequesting``)에서 이미 throw 되므로, 여기 도달한
    /// `response` 는 2xx 다. DELETE 등 일부 엔드포인트는 본문 없이 2xx 만 반환하므로 빈 본문은
    /// 성공으로 처리하고, 본문이 있으면 `APIResponse<EmptyResult>` 로 디코딩해 `isSuccess` 만
    /// 검증한다. 실패 응답은 ``CoreNetwork/RepositoryError/serverError(code:message:)`` 로
    /// 승격된다.
    func performVoidRequest(_ target: StudyRouter) async throws {
        let response = try await networkRequesting.request(target)
        guard !response.data.isEmpty else {
            return
        }
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        try apiResponse.validateSuccess()
    }

    /// 요청 본문에 담을 `String` 식별자를 `Int` 로 변환한다.
    ///
    /// 서버는 이 식별자들을 정수로 받는다. 값은 서버 응답(숫자 문자열)에서 오므로 보통 변환에
    /// 성공하지만, 변환할 수 없는 값이면 잘못된 요청을 보내는 대신 곧바로 에러를 던진다.
    /// 마땅한 전용 케이스가 없어 ``UMCFoundation/RepositoryError`` 의 `decodingError` 로 던진다.
    func intIdentifier(_ value: String, field: String) throws -> Int {
        guard let converted = Int(value) else {
            throw RepositoryError.decodingError(
                detail: "\(field) 식별자를 정수로 변환할 수 없습니다: \(value)"
            )
        }
        return converted
    }

    /// ``intIdentifier(_:field:)`` 의 배열 버전. 하나라도 변환에 실패하면 던진다.
    func intIdentifiers(_ values: [String], field: String) throws -> [Int] {
        try values.map { try intIdentifier($0, field: field) }
    }
}
