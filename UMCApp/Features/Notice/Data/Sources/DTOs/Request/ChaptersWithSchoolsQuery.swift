//
//  ChaptersWithSchoolsQuery.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation

/// 기수별 지부 및 소속 학교 목록 조회 Query DTO
///
/// `GET /api/v1/chapters/with-schools`
public struct ChaptersWithSchoolsQuery {

    // MARK: - Property

    /// 기수 ID
    public let gisuId: String

    // MARK: - Init

    public init(gisuId: String) {
        self.gisuId = gisuId
    }

    /// Query Parameter Dictionary 변환
    public var toParameters: [String: Any] {
        ["gisuId": gisuId]
    }
}
