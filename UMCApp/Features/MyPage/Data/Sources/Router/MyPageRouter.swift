//
//  MyPageRouter.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation
import Alamofire
import Moya
import CoreNetwork

/// 마이페이지 Feature API 라우터
///
/// 프로필 조회/수정 및 활동 로그/약관 API를 정의합니다.
public enum MyPageRouter {
    /// 약관 조회
    case getTerms(termsType: String)
}

// MARK: - BaseTargetType

extension MyPageRouter: BaseTargetType {
    public var path: String {
        switch self {
        case .getTerms(let termsType):
            return "/api/v1/terms/type/\(termsType)"
        }
    }
    
    public var method: Moya.Method {
        switch self {
        case .getTerms:
            return .get
        }
    }
    
    public var task: Moya.Task {
        switch self {
        case .getTerms:
            return .requestPlain
        }
    }   
}
