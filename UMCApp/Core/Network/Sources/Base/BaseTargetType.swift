//
//  BaseTargetType.swift
//  CoreNetwork
//
//  Created by euijjang97 on 3/6/26.
//

import Foundation
import Moya

/// 모든 API Target이 채택해야 하는 공통 프로토콜.
///
/// Moya `TargetType`을 확장하여 `baseURL`, `headers`, `validationType`의
/// 기본 구현을 제공합니다. 각 Feature의 Router는 이 프로토콜을 채택하고
/// `path`, `method`, `task`만 정의하면 됩니다.
///
/// ## 사용 예시
/// ```swift
/// public enum MyPageRouter {
///      case getTerms(termsType: String)
/// }
///
/// extension MyPageRouter: BaseTargetType {
///      public var path: String {
///         switch self {
///         case .getTerms(let termsType):
///             return "/api/v1/terms/type/\(termsType)"
///         }
///      }
///      public var method: Moya.Method {
///         switch self {
///         case .getTerms:
///             return .get
///         }
///      }
///      public var task: Moya.Task {
///         switch self {
///         case .getTerms:
///             return .requestPlain
///         }
///      }
/// }
/// ```
public protocol BaseTargetType: TargetType {}

extension BaseTargetType {
    /// 공통 base URL
    public var baseURL: URL {
        NetworkConfig.baseURL
    }
    
    /// 공통 기본 헤더
    public var headers: [String : String]? {
        NetworkConfig.defaultHeaders
    }
    
    /// 2x 응답만 성공으로 간주
    public var validationType: ValidationType {
        .successCodes
    }
}
