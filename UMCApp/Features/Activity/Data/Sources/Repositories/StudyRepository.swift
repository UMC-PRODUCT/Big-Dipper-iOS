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
/// - Note: 스터디 그룹 조회는 응답에 없는 `challengerId`·`nickname` 을 멤버 프로필
///   (`GET /api/v1/member/profile/{memberId}`)로 보강하므로 **멤버 수만큼 추가 요청**이 따른다.
///   중복 제거는 **한 번의 조회 안에서만** 적용되므로(페이지 단위), 전체 페이지를 순회하는
///   ``fetchStudyGroupDetails()`` 는 페이지에 걸쳐 같은 멤버를 다시 부를 수 있다. 서버가 두
///   필드를 그룹 응답에 포함해 주면 이 보강 단계는 통째로 사라진다.
public final class StudyRepository: StudyRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any NetworkRequesting
    private let context: StudyContextProviding
    private let decoder: JSONDecoder

    // MARK: - Constants

    private enum Constants {
        /// 운영진 스터디 그룹 전체 조회 시 페이지당 항목 수.
        static let studyGroupsPageSize = 100
        /// 멤버 프로필 보강 시 동시에 띄울 최대 요청 수.
        ///
        /// 한 페이지에 그룹이 100개면 멤버가 수백 명이 될 수 있어, 무제한으로 띄우면 서버와
        /// 연결 풀에 과부하가 걸린다. 창(window)을 두고 완료되는 만큼만 새로 채운다.
        static let memberSupplementConcurrencyLimit = 8

        /// 서버가 커리큘럼 미등록을 알리는 에러 코드.
        ///
        /// 서버 `CurriculumErrorCode.CURRICULUM_NOT_FOUND`(HTTP 404) 와 짝을 이룬다.
        static let curriculumNotRegisteredCode = "CURRICULUM-0001"
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

    /// 커리큘럼 개요를 한 번 조회해 진행률과 주차별 미션을 함께 매핑한다.
    ///
    /// 두 결과 모두 같은 `CurriculumDTO` 에서 파생되므로 네트워크 요청은 1회만 발생한다.
    public func fetchCurriculumOverview() async throws -> CurriculumOverview {
        let curriculum = try await fetchCurriculum()
        let platform = UMCPartType(apiValue: curriculum.part)?.name ?? curriculum.part

        return CurriculumOverview(
            progress: curriculum.dto.toCurriculumProgress(part: curriculum.part),
            missions: curriculum.dto.toMissionCards(platform: platform)
        )
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
        let page = try apiResponse.unwrap()
        let supplements = await fetchMemberSupplements(memberIDs: page.allMemberIDs)
        return page.toDomain(supplementsByMemberID: supplements)
    }

    public func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        let response = try await networkRequesting.request(
            StudyRouter.getStudyGroupDetail(groupId: groupId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<StudyGroupDetailDTO>.self,
            from: response.data
        )
        let detail = try apiResponse.unwrap()
        let supplements = await fetchMemberSupplements(memberIDs: detail.allMemberIDs)
        return detail.toDomain(supplementsByMemberID: supplements)
    }

    public func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        let profile = try await fetchMemberProfile(memberId: memberId)
        return selectChallengerID(
            from: profile,
            memberID: memberId,
            preferredGeneration: preferredGeneration
        )
    }

    public func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        let response = try await networkRequesting.request(StudyRouter.getStudyGroupNames)
        let apiResponse = try decoder.decode(
            APIResponse<StudyGroupNamesDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }

    // MARK: - 스터디원 제출 현황

    /// 스터디원 제출 현황 한 페이지를 조회한다.
    ///
    /// 그룹 상세 조회와 달리 멤버 프로필 보강이 필요 없다 — 서버가 이름·학교·프로필을
    /// 응답에 함께 내려주기 때문이다.
    public func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        let response = try await networkRequesting.request(
            StudyRouter.getStudyMemberSubmissions(
                query: StudyMemberSubmissionQuery(
                    studyGroupId: studyGroupId,
                    weekNos: weekNos,
                    cursor: cursor,
                    size: size
                )
            )
        )
        let apiResponse = try decoder.decode(
            APIResponse<StudyMemberSubmissionPageDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
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
    /// 커리큘럼이 아직 등록되지 않아 서버가 `CURRICULUM-0001` 로 응답하면
    /// ``DomainError/curriculumNotRegistered`` 로 승격한다. 학기 초에는 미등록이 정상
    /// 상황이라 화면이 오류 카드 대신 전용 안내를 띄워야 하기 때문이다. 그 외 실패는
    /// 원본 에러를 그대로 전파한다.
    ///
    /// 요청을 `do` 블록 안에 두어야 비-2xx 응답으로 발생한
    /// ``NetworkError/requestFailed(statusCode:data:)`` 가 이 변환을 거친다.
    ///
    /// - Returns: 디코딩한 ``CurriculumDTO`` 와 조회에 사용한 파트 문자열
    func fetchCurriculum() async throws -> (dto: CurriculumDTO, part: String) {
        guard let gisuId = context.gisuId else {
            throw DomainError.curriculumUnavailableForGeneration
        }
        let part = context.part
        let response: Response
        do {
            response = try await networkRequesting.request(
                StudyRouter.getCurriculum(
                    query: CurriculumOverviewQuery(gisuId: gisuId, part: part, weekNo: nil)
                )
            )
        } catch let error as NetworkError {
            throw Self.mapCurriculumNotRegistered(error) ?? error
        }
        let apiResponse = try decoder.decode(
            APIResponse<CurriculumDTO>.self,
            from: response.data
        )
        return (try apiResponse.unwrap(), part)
    }

    /// 커리큘럼 조회 실패 본문이 미등록 코드인지 판별한다.
    ///
    /// 미등록 코드일 때만 ``DomainError/curriculumNotRegistered`` 를 돌려주고, 다른 코드·
    /// 비-`requestFailed` 실패는 `nil` 을 반환해 원본 에러가 그대로 전파되게 한다. 범위를
    /// 코드로 좁히지 않으면 401·5xx 까지 미등록 안내로 뭉개진다.
    ///
    /// - Note: 본문 파싱에 `JSONSerialization` 을 쓰는 이유는 서버가 실패 응답의 `result` 에
    ///   객체가 아니라 **문자열**(예외 메시지)을 담기 때문이다. `APIResponse<EmptyResult>` 로
    ///   디코딩하면 그 문자열에서 실패해 `code` 를 읽지 못한다.
    static func mapCurriculumNotRegistered(_ error: NetworkError) -> DomainError? {
        guard
            case .requestFailed(_, let data) = error,
            let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["code"] as? String == Constants.curriculumNotRegisteredCode
        else {
            return nil
        }
        return .curriculumNotRegistered
    }

    // MARK: - 멤버 프로필 보강

    /// 스터디 그룹 응답에 없는 멤버 정보(`challengerId`·`nickname`)를 멤버 프로필로 해석한다.
    ///
    /// 서버 `StudyGroupMemberResponse` 는 두 값을 주지 않으므로 `memberId` 마다
    /// `GET /api/v1/member/profile/{memberId}` 를 조회한다. 중복 `memberId` 는 한 번만 부르고,
    /// 동시 요청은 ``Constants/memberSupplementConcurrencyLimit`` 개로 제한한다.
    ///
    /// 보강은 부가 정보이므로 실패해도 그룹 목록 자체는 반환한다. 취소된 뒤 호출되면 요청을
    /// 아예 시작하지 않고, 진행 중 취소되면 남은 멤버 없이 그때까지의 결과만 돌려준다
    /// (이 경로의 결과는 취소된 호출자가 어차피 버린다).
    ///
    /// - Parameter memberIDs: 보강할 멤버 식별자 목록 (중복 허용)
    /// - Returns: `memberId` → 보강 정보. 조회에 실패한 멤버는 매핑에 담기지 않는다.
    func fetchMemberSupplements(
        memberIDs: [String]
    ) async -> [String: StudyGroupMemberSupplement] {
        let uniqueIDs = Array(Set(memberIDs))
        // 이 파일은 Moya 를 import 하므로 `Task` 는 `Moya.Task` 로 해석된다. 동시성 타입을 쓰려면
        // `_Concurrency` 로 한정해야 한다.
        guard !uniqueIDs.isEmpty, !_Concurrency.Task.isCancelled else { return [:] }

        var result: [String: StudyGroupMemberSupplement] = [:]
        var nextIndex = 0

        await withTaskGroup(of: (String, StudyGroupMemberSupplement)?.self) { group in
            let initialCount = min(Constants.memberSupplementConcurrencyLimit, uniqueIDs.count)
            while nextIndex < initialCount {
                let memberID = uniqueIDs[nextIndex]
                group.addTask { await self.makeSupplementEntry(memberID: memberID) }
                nextIndex += 1
            }

            // 하나가 끝날 때마다 다음 하나를 채워 in-flight 개수를 창 크기로 유지한다.
            while let entry = await group.next() {
                if let entry {
                    result[entry.0] = entry.1
                }
                guard nextIndex < uniqueIDs.count else { continue }
                let memberID = uniqueIDs[nextIndex]
                group.addTask { await self.makeSupplementEntry(memberID: memberID) }
                nextIndex += 1
            }
        }

        return result
    }

    /// 단일 멤버의 보강 정보를 조회한다.
    ///
    /// 개별 멤버 조회 실패가 그룹 목록 전체를 막지 않도록 에러를 삼키고 `nil` 을 반환한다.
    /// 이 경우 해당 멤버는 `challengerID`·`nickname` 이 `nil` 로 남는다.
    func makeSupplementEntry(
        memberID: String
    ) async -> (String, StudyGroupMemberSupplement)? {
        do {
            let profile = try await fetchMemberProfile(memberId: memberID)
            let supplement = StudyGroupMemberSupplement(
                challengerID: selectChallengerID(
                    from: profile,
                    memberID: memberID,
                    preferredGeneration: nil
                ),
                nickname: profile.nickname
            )
            return (memberID, supplement)
        } catch {
            return nil
        }
    }

    /// 멤버 프로필을 조회해 ``MemberProfileDTO`` 로 디코딩한다.
    func fetchMemberProfile(memberId: String) async throws -> MemberProfileDTO {
        let response = try await networkRequesting.request(
            StudyRouter.getMemberProfile(memberId: memberId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<MemberProfileDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }

    /// 멤버 프로필의 기수별 챌린저 레코드 중 현재 맥락에 맞는 `challengerId` 를 고른다.
    ///
    /// 우선순위는 요청 기수 → 컨텍스트 기수(`gisuId`) → 첫 유효 레코드 순이다.
    ///
    /// - Parameters:
    ///   - profile: 조회한 멤버 프로필
    ///   - memberID: 대상 멤버 식별자 (레코드가 다른 멤버 것을 섞어 주는 경우를 걸러낸다)
    ///   - preferredGeneration: 우선 매칭할 기수 번호. `nil` 이면 컨텍스트 기수부터 본다.
    /// - Returns: 선택된 `challengerId`. 유효 레코드가 없으면 `nil`.
    func selectChallengerID(
        from profile: MemberProfileDTO,
        memberID: String,
        preferredGeneration: String?
    ) -> String? {
        let records = profile.challengerRecords.filter {
            $0.memberId == memberID && !$0.challengerId.isEmpty
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

    // MARK: - 공통 요청

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
