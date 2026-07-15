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
    /// 특정 멤버 프로필 조회 (`GET /api/v1/member/profile/{memberId}`)
    case getMemberProfile(memberId: Int)
    /// 특정 챌린저 프로필 조회
    case getChallengerProfile(challengerId: Int)
    /// 기존 챌린저 기록 추가
    case addChallengerRecord(code: String)
    /// 회원 정보 수정(프로필 이미지 ID 반영)
    case patchMember(request: UpdateMemberProfileImageRequestDTO)
    /// 회원 정보 수정(외부 링크 반영)
    case patchMemberProfileLinks(request: UpdateMemberProfileLinksRequestDTO)
    /// 회원 탈퇴
    case deleteMember
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
        case .getMemberProfile(let memberId):
            return "/api/v1/member/profile/\(memberId)"
        case .getChallengerProfile(let challengerId):
            return "/api/v1/challenger/\(challengerId)"
        case .addChallengerRecord:
            return "/api/v1/challenger-record/member"
        case .patchMember:
            return "/api/v1/member"
        case .patchMemberProfileLinks:
            return "/api/v1/member/profile/links"
        case .deleteMember:
            return "/api/v1/member"
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
        case .getMemberProfile:
            return .get
        case .getChallengerProfile:
            return .get
        case .addChallengerRecord:
            return .post
        case .patchMember:
            return .patch
        case .patchMemberProfileLinks:
            return .patch
        case .deleteMember:
            return .delete
        case .getMyPosts:
            return .get
        case .getCommentedPosts:
            return .get
        case .getScrappedPosts:
            return .get
        case .getTerms:
            return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .getMemberProfile, .getChallengerProfile, .deleteMember:
            return .requestPlain
        case .addChallengerRecord(let code):
            return .requestJSONEncodable(
                AddChallengerRecordRequestDTO(code: code)
            )
        case .patchMember(let request):
            return .requestJSONEncodable(request)
        case .patchMemberProfileLinks(let request):
            return .requestJSONEncodable(request)
        case .getMyPosts(let query), .getCommentedPosts(let query), .getScrappedPosts(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getTerms:
            return .requestPlain
        }
    }
}
