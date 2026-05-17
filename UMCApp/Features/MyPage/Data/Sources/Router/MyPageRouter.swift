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
    /// 약관 조회 (`GET /api/v1/terms/type/{termsType}`)
    case getTerms(termsType: String)
}

// MARK: - BaseTargetType

extension MyPageRouter: BaseTargetType {
    public var path: String {
        switch self {
        case .getMyProfile:
            return "/api/v1/member/me"
        case .getTerms(let termsType):
            return "/api/v1/terms/type/\(termsType)"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getMyProfile, .getTerms:
            return .get
        }
    }

    public var task: Moya.Task {
        switch self {
        case .getMyProfile, .getTerms:
            return .requestPlain
        }
    }
}
