//
//  ChallengerSearchRouter.swift
//  AppProduct
//
//  Created by euijjang97 on 2/13/26.
//

import Foundation
internal import Alamofire
import Moya

/// 챌린저 검색 API 라우터
///
/// 챌린저 검색에 필요한 API 엔드포인트를 정의합니다.
///
/// - SeeAlso: ``ChallengerSearchRepository``, ``ChallengerSearchRequestDTO``
enum ChallengerSearchRouter {
    /// 챌린저 커서 검색 (Cursor 기반 페이지네이션)
    case searchCursor(query: ChallengerSearchRequestDTO)
}

extension ChallengerSearchRouter: BaseTargetType {

    // MARK: - Path

    var path: String {
        switch self {
        case .searchCursor:
            return "/api/v1/challenger/search/cursor"
        }
    }

    // MARK: - Method

    var method: Moya.Method {
        switch self {
        case .searchCursor:
            return .get
        }
    }

    // MARK: - Task

    var task: Moya.Task {
        switch self {
        case .searchCursor(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        }
    }
}
