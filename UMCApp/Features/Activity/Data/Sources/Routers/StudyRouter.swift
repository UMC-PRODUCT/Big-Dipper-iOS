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

/// Study(Activity) Feature 조회 API 라우터.
///
/// 조회 계열 case 만 정의합니다. CRUD case(생성/수정/삭제/멤버·멘토/일정 연결)는
/// 후속 작업에서 동일 enum 에 case 추가만으로 확장합니다.
///
/// 연관값(Query DTO·식별자 String)이 모두 `Sendable` 이므로 라우터도 `Sendable`.
/// 동시성 경계를 넘어 안전하게 전달되며, 테스트의 파라미터화(`@Test(arguments:)`)도 가능.
enum StudyRouter: Sendable {
    /// 커리큘럼 개요 조회 — `GET /api/v2/curriculums/overview`
    case getCurriculum(query: CurriculumOverviewQuery)
    /// 운영 스터디 그룹 페이지 조회 — `GET /api/v1/study-groups/managed`
    case getMyStudyGroups(query: MyStudyGroupsQuery)
    /// 단일 스터디 그룹 상세 조회 — `GET /api/v1/study-groups/{groupId}`
    case getStudyGroupDetail(groupId: String)
    /// 멤버 프로필 조회 (resolveChallengerId 용) — `GET /api/v1/member/profile/{memberId}`
    case getMemberProfile(memberId: String)
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
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
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
        case .getStudyGroupDetail, .getMemberProfile:
            return .requestPlain
        }
    }
}
