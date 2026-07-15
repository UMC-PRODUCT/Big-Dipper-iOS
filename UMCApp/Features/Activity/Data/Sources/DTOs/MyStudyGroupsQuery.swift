//
//  MyStudyGroupsQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// `GET /api/v1/study-groups/managed` 페이지네이션 쿼리 파라미터.
///
/// `cursor` 는 첫 페이지에서 `nil`. 서버 `nextCursor` 는 불투명(opaque) 토큰이라
/// 숫자가 아닐 수 있으므로(`"cursor-2"` 등) 받은 값을 그대로 echo 하도록 `String` 으로 보냅니다.
/// `size` 만 페이지 크기 정수입니다.
struct MyStudyGroupsQuery {
    let cursor: String?
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
