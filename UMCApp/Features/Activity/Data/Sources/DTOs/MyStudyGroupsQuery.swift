//
//  MyStudyGroupsQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// `GET /api/v1/study-groups/managed` 페이지네이션 쿼리 파라미터.
///
/// `cursor` 는 첫 페이지에서 `nil`. `cursor`/`size` 는 페이지네이션 정수이며
/// 서버 식별자가 아니므로 `Int` 를 유지합니다.
struct MyStudyGroupsQuery {
    let cursor: Int?
    let size: Int

    /// Moya `URLEncoding.queryString` 직렬화용 파라미터 사전.
    var toParameters: [String: Any] {
        var parameters: [String: Any] = [
            "size": size
        ]
        if let cursor {
            parameters["cursor"] = cursor
        }
        return parameters
    }
}
