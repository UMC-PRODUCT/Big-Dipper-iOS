//
//  CurriculumOverviewQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation

/// `GET /api/v2/curriculums/overview` 쿼리 파라미터.
///
/// 서버 식별자 `gisuId` 는 전 레이어 `String` 통일 규칙을 따릅니다.
/// `weekNo` 는 주차 번호(클라이언트 입력)로 미지정 시 `nil`.
struct CurriculumOverviewQuery {
    let gisuId: String
    let part: String
    let weekNo: Int?

    /// Moya `URLEncoding.queryString` 직렬화용 파라미터 사전.
    var toParameters: [String: Any] {
        var parameters: [String: Any] = [
            "gisuId": gisuId,
            "part": part
        ]
        if let weekNo {
            parameters["weekNo"] = weekNo
        }
        return parameters
    }
}
