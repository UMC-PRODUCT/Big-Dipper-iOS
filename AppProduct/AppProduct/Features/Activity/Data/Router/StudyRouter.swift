//
//  StudyRouter.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation
internal import Alamofire
import Moya

/// Study Feature API 라우터
enum StudyRouter {
    case getCurriculum(gisuId: Int, part: String, weekNo: Int?)
    case linkStudyGroupSchedule(body: StudyGroupScheduleCreateRequestDTO)
    case getMyStudyGroups(cursor: Int?, size: Int)
    case getStudyGroupDetail(groupId: Int)
    case getMemberProfile(memberId: Int)
    case createStudyGroup(body: StudyGroupCreateRequestDTO)
    case updateStudyGroup(groupId: Int, body: StudyGroupUpdateRequestDTO)
    case deleteStudyGroup(groupId: Int)
    case addStudyGroupMember(groupId: Int, memberId: Int)
    case removeStudyGroupMember(groupId: Int, memberId: Int)
    case addStudyGroupMentor(groupId: Int, mentorId: Int)
    case removeStudyGroupMentor(groupId: Int, mentorId: Int)
    case createChallengerPoint(challengerId: Int, body: ChallengerPointCreateRequestDTO)
    case deleteChallengerPoint(challengerPointId: Int)
    case searchChallengersOffset(page: Int, size: Int, schoolId: Int)
}

extension StudyRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .getCurriculum:
            return "/api/v2/curriculums/overview"
        case .linkStudyGroupSchedule:
            return "/api/v1/study-groups/schedules"
        case .getMyStudyGroups:
            return "/api/v1/study-groups/managed"
        case .getStudyGroupDetail(let groupId):
            return "/api/v1/study-groups/\(groupId)"
        case .getMemberProfile(let memberId):
            return "/api/v1/member/profile/\(memberId)"
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
        case .createChallengerPoint(let challengerId, _):
            return "/api/v1/challenger/\(challengerId)/points"
        case .deleteChallengerPoint(let challengerPointId):
            return "/api/v1/challenger/points/\(challengerPointId)"
        case .searchChallengersOffset:
            return "/api/v1/challenger/search/offset"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .createStudyGroup:
            return .post
        case .createChallengerPoint:
            return .post
        case .deleteChallengerPoint:
            return .delete
        case .searchChallengersOffset:
            return .get
        case .linkStudyGroupSchedule:
            return .post
        case .updateStudyGroup:
            return .patch
        case .deleteStudyGroup:
            return .delete
        case .addStudyGroupMember,
             .addStudyGroupMentor:
            return .patch
        case .removeStudyGroupMember,
             .removeStudyGroupMentor:
            return .delete
        case .getCurriculum,
             .getMyStudyGroups,
             .getStudyGroupDetail,
             .getMemberProfile:
            return .get
        }
    }

    // MARK: - Task

    var task: Task {
        switch self {
        case .getCurriculum(let gisuId, let part, let weekNo):
            var parameters: [String: Any] = [
                "gisuId": gisuId,
                "part": part
            ]
            if let weekNo {
                parameters["weekNo"] = weekNo
            }
            return .requestParameters(
                parameters: parameters,
                encoding: URLEncoding.queryString
            )
        case .linkStudyGroupSchedule(let body):
            return .requestJSONEncodable(body)
        case .getMyStudyGroups(let cursor, let size):
            var parameters: [String: Any] = [
                "size": size
            ]
            if let cursor {
                parameters["cursor"] = cursor
            }
            return .requestParameters(
                parameters: parameters,
                encoding: URLEncoding.queryString
            )
        case .getStudyGroupDetail,
             .getMemberProfile:
            return .requestPlain
        case .createStudyGroup(let body):
            return .requestJSONEncodable(body)
        case .updateStudyGroup(_, let body):
            return .requestJSONEncodable(body)
        case .createChallengerPoint(_, let body):
            return .requestJSONEncodable(body)
        case .deleteChallengerPoint:
            return .requestPlain
        case .deleteStudyGroup,
             .addStudyGroupMember,
             .removeStudyGroupMember,
             .addStudyGroupMentor,
             .removeStudyGroupMentor:
            return .requestPlain
        case .searchChallengersOffset(let page, let size, let schoolId):
            return .requestParameters(
                parameters: [
                    "page": page,
                    "size": size,
                    "schoolId": schoolId
                ],
                encoding: URLEncoding.queryString
            )
        }
    }
}
