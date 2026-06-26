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
/// 스터디 그룹 조회, 챌린저 ID 해석)은 ``StudyRouter`` 조회 case 로 실구현하고, 운영진 스터디
/// 그룹 CRUD·일정 연결은 라우터 case 가 아직 없어 미구현 에러를 던지는 스텁으로 둔다(8차에서
/// 실구현). ``NetworkRequesting`` 으로 요청을 보낸 뒤 `APIResponse<DTO>` 를 디코딩하고
/// `toDomain()` 으로 도메인 모델에 매핑한다.
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
        var cursor: Int?
        var hasNext = true

        while hasNext {
            let page = try await fetchStudyGroupDetailsPage(
                cursor: cursor,
                size: Constants.studyGroupsPageSize
            )
            allDetails.append(contentsOf: page.content)

            hasNext = page.hasNext
            cursor = page.nextCursor.flatMap(Int.init)
            // 다음 페이지가 있다고 했으나 커서가 없으면 무한 루프 방지를 위해 중단한다.
            if hasNext && cursor == nil {
                break
            }
        }

        return allDetails
    }

    public func fetchStudyGroupDetailsPage(
        cursor: Int?,
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
        preferredGeneration: Int?
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

        if let preferredGeneration, preferredGeneration > 0,
           let matched = records.first(where: { $0.gisu == preferredGeneration }) {
            return matched.challengerId
        }

        if let preferredGisuId = context.gisuId,
           let matched = records.first(where: { $0.gisuId == preferredGisuId }) {
            return matched.challengerId
        }

        return records.first?.challengerId
    }

    // MARK: - 운영진 스터디 그룹 CRUD (8차 실구현 — 미구현 스텁)

    public func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "createStudyGroup")
    }

    public func updateStudyGroup(groupId: String, name: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "updateStudyGroup")
    }

    public func deleteStudyGroup(groupId: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "deleteStudyGroup")
    }

    public func addStudyGroupMember(groupId: String, memberId: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "addStudyGroupMember")
    }

    public func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "removeStudyGroupMember")
    }

    public func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "addStudyGroupMentor")
    }

    public func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "removeStudyGroupMentor")
    }

    public func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        // TODO: 8차 CRUD 구현 - [26.06.24] jaewon
        throw StudyRepositoryError.unimplemented(operation: "linkStudyGroupSchedule")
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
}

// MARK: - StudyRepositoryError

/// ``StudyRepository`` 의 미구현 스텁 메서드가 호출됐음을 알리는 에러.
///
/// 운영진 스터디 그룹 CRUD·일정 연결은 라우터 case 가 추가되는 8차에서 실구현된다.
/// 그 전까지 호출되면 본 에러를 던져 "아직 미구현" 임을 명확히 한다.
enum StudyRepositoryError: Error, Equatable {

    /// 아직 구현되지 않은 운영진 스터디 CRUD/연결 작업 (`operation`: 메서드 이름)
    case unimplemented(operation: String)
}
