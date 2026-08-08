//
//  AuthorizationRouter.swift
//  CoreNetwork
//
//  Created by euijjang97 on 8/8/26.
//

import Foundation
import Moya

/// 공용 리소스 권한 API 라우터
public enum AuthorizationRouter: BaseTargetType {
    /// 리소스 권한 조회
    case getResourcePermission(query: ResourcePermissionQuery)

    public var path: String {
        switch self {
        case .getResourcePermission:
            return "/api/v1/authorization/resource-permission"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getResourcePermission:
            return .get
        }
    }

    public var task: Task {
        switch self {
        case .getResourcePermission(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        }
    }
}
