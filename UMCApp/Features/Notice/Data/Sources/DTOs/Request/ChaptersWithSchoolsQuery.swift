//
//  ChaptersWithSchoolsQuery.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation

/// 기수별 지부/학교 목록 조회 Query DTO
///
/// `GET /api/v1/chapters/with-schools`
public struct ChaptersWithSchoolsQuery: Encodable {

    // MARK: - Property

    public let gisuId: String

    // MARK: - Init

    public init(gisuId: String) {
        self.gisuId = gisuId
    }

    // MARK: - Function

    public var toParameters: [String: Any] {
        ["gisuId": gisuId]
    }
}
