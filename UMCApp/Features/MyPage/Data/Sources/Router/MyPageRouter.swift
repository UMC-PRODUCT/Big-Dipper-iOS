//
//  MyPageRouter.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation
import Moya
import CoreNetwork

/// 마이페이지 Feature API 라우터
///
/// `BaseTargetType`을 통해 baseURL/headers/validation 기본 동작을 상속받습니다.
/// 각 case의 path/method/task는 본 extension에서 정의합니다.
public enum MyPageRouter {
    /// 내 프로필 조회 (`GET /api/v1/member/me`)
    case getMyProfile
    /// 특정 멤버 프로필 조회 (`GET /api/v1/member/profile/{memberId}`)
    case getMemberProfile(memberId: String)
    /// 내가 쓴 글 목록 (`GET /api/v1/posts/my`)
    case getMyPosts(query: MyPagePostListQueryDTO)
    /// 댓글 단 글 목록 (`GET /api/v1/posts/commented`)
    case getCommentedPosts(query: MyPagePostListQueryDTO)
    /// 스크랩한 글 목록 (`GET /api/v1/posts/scrapped`)
    case getScrappedPosts(query: MyPagePostListQueryDTO)
    /// 약관 조회 (`GET /api/v1/terms/type/{termsType}`)
    case getTerms(termsType: String)
}

// MARK: - BaseTargetType

extension MyPageRouter: BaseTargetType {
    public var path: String {
        switch self {
        case .getMyProfile:
            return "/api/v1/member/me"
        case .getMemberProfile(let memberId):
            return "/api/v1/member/profile/\(memberId)"
        case .getMyPosts:
            return "/api/v1/posts/my"
        case .getCommentedPosts:
            return "/api/v1/posts/commented"
        case .getScrappedPosts:
            return "/api/v1/posts/scrapped"
        case .getTerms(let termsType):
            return "/api/v1/terms/type/\(termsType)"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getMyProfile,
             .getMemberProfile,
             .getMyPosts,
             .getCommentedPosts,
             .getScrappedPosts,
             .getTerms:
            return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .getMyProfile, .getMemberProfile, .getTerms:
            return .requestPlain
        case .getMyPosts(let query),
             .getCommentedPosts(let query),
             .getScrappedPosts(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        }
    }
}
