//
//  StudyRouter.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Moya
import CoreNetwork
internal import Alamofire

/// Study(Activity) Feature API 라우터.
///
/// 조회 계열(커리큘럼/운영 스터디 그룹/멤버 프로필)과 운영진 스터디 그룹 CRUD·일정 연결,
/// 멤버·포인트 계열(오프셋 검색·상벌점 부여/삭제·챌린저 프로필)을 단일 enum 으로 묶어
/// 표현합니다.
///
/// 연관값(Query/Request DTO·식별자 String)이 모두 `Sendable` 이므로 라우터도 `Sendable`.
/// 동시성 경계를 넘어 안전하게 전달되며, 테스트의 파라미터화(`@Test(arguments:)`)도 가능.
///
/// - Note: 스터디 그룹 엔드포인트는 레거시와 동일하게 `/api/v1/study-groups` 경로를 사용합니다
///   (커리큘럼만 `/api/v2`). 쿼리는 Query DTO 의 `toParameters`, 바디는 Request DTO 로
///   캡슐화하고 `task` 에 인라인 딕셔너리를 두지 않습니다.
enum StudyRouter: Sendable {
    /// 커리큘럼 개요 조회 — `GET /api/v2/curriculums/overview`
    case getCurriculum(query: CurriculumOverviewQuery)
    /// 운영 스터디 그룹 페이지 조회 — `GET /api/v1/study-groups/managed`
    case getMyStudyGroups(query: MyStudyGroupsQuery)
    /// 단일 스터디 그룹 상세 조회 — `GET /api/v1/study-groups/{groupId}`
    case getStudyGroupDetail(groupId: String)
    /// 멤버 프로필 조회 (resolveChallengerId · 멤버 관리 용) — `GET /api/v1/member/profile/{memberId}`
    case getMemberProfile(memberId: String)

    // MARK: - 멤버 / 포인트

    /// 학교 단위 챌린저 오프셋 검색 — `GET /api/v1/challenger/search/offset`
    case searchChallengersOffset(query: ChallengerSearchQuery)
    /// 챌린저 포인트 부여 — `POST /api/v1/challenger/{challengerId}/points`
    case createChallengerPoint(challengerId: String, body: ChallengerPointCreateRequestDTO)
    /// 챌린저 포인트 삭제 — `DELETE /api/v1/challenger/points/{challengerPointId}`
    case deleteChallengerPoint(challengerPointId: String)
    /// 챌린저 프로필 조회 (포인트 히스토리 용) — `GET /api/v1/challenger/{challengerId}`
    case getChallengerProfile(challengerId: String)

    // MARK: - 운영진 스터디 그룹 CRUD / 일정 연결

    /// 스터디 그룹 생성 — `POST /api/v1/study-groups`
    case createStudyGroup(body: StudyGroupCreateRequestDTO)
    /// 스터디 그룹 수정(이름) — `PATCH /api/v1/study-groups/{groupId}`
    case updateStudyGroup(groupId: String, body: StudyGroupUpdateRequestDTO)
    /// 스터디 그룹 삭제 — `DELETE /api/v1/study-groups/{groupId}`
    case deleteStudyGroup(groupId: String)
    /// 스터디원 추가 — `PATCH /api/v1/study-groups/{groupId}/members/{memberId}`
    case addStudyGroupMember(groupId: String, memberId: String)
    /// 스터디원 제거 — `DELETE /api/v1/study-groups/{groupId}/members/{memberId}`
    case removeStudyGroupMember(groupId: String, memberId: String)
    /// 멘토(파트장) 추가 — `PATCH /api/v1/study-groups/{groupId}/mentors/{mentorId}`
    case addStudyGroupMentor(groupId: String, mentorId: String)
    /// 멘토(파트장) 제거 — `DELETE /api/v1/study-groups/{groupId}/mentors/{mentorId}`
    case removeStudyGroupMentor(groupId: String, mentorId: String)
    /// 일정-스터디 그룹 연결 — `POST /api/v1/study-groups/schedules`
    case linkStudyGroupSchedule(body: StudyGroupScheduleCreateRequestDTO)
}

extension StudyRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getCurriculum:
            return "/api/v2/curriculums/overview"
        case .getMyStudyGroups:
            return "/api/v1/study-groups/managed"
        case .getStudyGroupDetail(let groupId):
            return "/api/v1/study-groups/\(groupId)"
        case .getMemberProfile(let memberId):
            return "/api/v1/member/profile/\(memberId)"
        case .searchChallengersOffset:
            return "/api/v1/challenger/search/offset"
        case .createChallengerPoint(let challengerId, _):
            return "/api/v1/challenger/\(challengerId)/points"
        case .deleteChallengerPoint(let challengerPointId):
            return "/api/v1/challenger/points/\(challengerPointId)"
        case .getChallengerProfile(let challengerId):
            return "/api/v1/challenger/\(challengerId)"
        case .createStudyGroup:
            return "/api/v1/study-groups"
        case .updateStudyGroup(let groupId, _):
            return "/api/v1/study-groups/\(groupId)"
        case .deleteStudyGroup(let groupId):
            return "/api/v1/study-groups/\(groupId)"
        case .addStudyGroupMember(let groupId, let memberId),
             .removeStudyGroupMember(let groupId, let memberId):
            return "/api/v1/study-groups/\(groupId)/members/\(memberId)"
        case .addStudyGroupMentor(let groupId, let mentorId),
             .removeStudyGroupMentor(let groupId, let mentorId):
            return "/api/v1/study-groups/\(groupId)/mentors/\(mentorId)"
        case .linkStudyGroupSchedule:
            return "/api/v1/study-groups/schedules"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .getCurriculum,
             .getMyStudyGroups,
             .getStudyGroupDetail,
             .getMemberProfile,
             .searchChallengersOffset,
             .getChallengerProfile:
            return .get
        case .createStudyGroup,
             .linkStudyGroupSchedule,
             .createChallengerPoint:
            return .post
        case .updateStudyGroup,
             .addStudyGroupMember,
             .addStudyGroupMentor:
            return .patch
        case .deleteStudyGroup,
             .removeStudyGroupMember,
             .removeStudyGroupMentor,
             .deleteChallengerPoint:
            return .delete
        }
    }

    // MARK: - Task

    var task: Task {
        switch self {
        case .getCurriculum(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getMyStudyGroups(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .searchChallengersOffset(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .createStudyGroup(let body):
            return .requestJSONEncodable(body)
        case .updateStudyGroup(_, let body):
            return .requestJSONEncodable(body)
        case .linkStudyGroupSchedule(let body):
            return .requestJSONEncodable(body)
        case .createChallengerPoint(_, let body):
            return .requestJSONEncodable(body)
        case .getStudyGroupDetail,
             .getMemberProfile,
             .getChallengerProfile,
             .deleteStudyGroup,
             .addStudyGroupMember,
             .removeStudyGroupMember,
             .addStudyGroupMentor,
             .removeStudyGroupMentor,
             .deleteChallengerPoint:
            return .requestPlain
        }
    }
}
