//
//  NoticeReadStatusListQuery.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 공지 열람 현황 상세 조회 Query DTO
///
/// `GET /api/v1/notices/{noticeId}/read-status`
struct NoticeReadStatusListQuery: Encodable {
    /// 이전 페이지의 마지막 항목 ID (커서 기반)
    let cursorId: Int
    /// 필터 타입 (운영진 / 챌린저 등)
    let filterType: String
    /// 조직(지부/학교) ID 목록
    let organizationIds: [Int]
    /// 열람 상태 필터 (READ / UNREAD)
    let status: String

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        [
            "cursorId": cursorId,
            "filterType": filterType,
            "organizationIds": organizationIds,
            "status": status
        ]
    }
}
