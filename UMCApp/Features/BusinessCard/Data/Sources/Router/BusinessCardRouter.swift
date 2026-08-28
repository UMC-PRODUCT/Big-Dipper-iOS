//
//  BusinessCardRouter.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import Moya
import CoreNetwork

/// 마이페이지 행 카운트 전용 라우터.
///
/// 스터디·스크랩 엔드포인트는 Activity·MyPage Router에도 있지만, 크로스 피처 import
/// 금지 원칙에 따라 자체 케이스로 복제한다 (선례: `/member/profile/{id}`가
/// MyPageRouter·StudyRouter 양쪽에 존재). path 변경은 각 Router의 계약 테스트가 잡는다.
enum BusinessCardRouter {
    /// **관리 가능한** 스터디 목록 (`GET /api/v1/study-groups/managed`) — 항목 수만 쓴다.
    ///
    /// - Important: `managed` 는 「내가 참여한」이 아니라 「내가 관리할 수 있는」이다
    ///   (서버 `StudyGroupController`·`StudyRouter.getStudyGroupNames` 와 같은 의미).
    ///   그래서 운영진이 아닌 챌린저에게 이 카운트는 항상 0이다. 참여 기준 목록 API가
    ///   서버에 없어 클라이언트에서 메울 수 없다 (#1222).
    case getMyStudyGroups(query: StudyCountQueryDTO)
    /// 스크랩 글 페이지 (`GET /api/v1/posts/scrapped`) — totalElements만 쓴다.
    case getScrappedPosts(query: ScrappedCountQueryDTO)
    /// 상대 프로필 (`GET /api/v1/member/profile/{memberId}`) — QR 딥링크 스캔이 명함을 복원한다.
    ///
    /// MyPageRouter에도 같은 경로가 있지만 그쪽은 `memberId: Int`라 서버 정수를 전 레이어
    /// `String`으로 통일하는 규약에서 벗어나 있다. 복제하는 김에 `String`으로 맞춘다.
    case getMemberProfile(memberId: String)
}

extension BusinessCardRouter: BaseTargetType {
    var path: String {
        switch self {
        case .getMyStudyGroups: return "/api/v1/study-groups/managed"
        case .getScrappedPosts: return "/api/v1/posts/scrapped"
        case .getMemberProfile(let memberId): return "/api/v1/member/profile/\(memberId)"
        }
    }

    var method: Moya.Method { .get }

    var task: Moya.Task {
        switch self {
        case .getMyStudyGroups(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getScrappedPosts(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getMemberProfile:
            return .requestPlain
        }
    }
}
