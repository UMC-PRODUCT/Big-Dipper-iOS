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
public enum MyPageRouter {
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
