//
//  NoticeReadStatusListQuery.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 열람 현황 상세 조회 Query DTO
///
/// `GET /api/v1/notices/{noticeId}/read-status`
public struct NoticeReadStatusListQuery: Encodable {
    /// 이전 페이지의 마지막 항목 ID (커서 기반)
    public let cursorId: String
    /// 필터 타입 (운영진 / 챌린저 등)
    public let filterType: String
    /// 조직(지부/학교) ID 목록
    public let organizationIds: [String]
    /// 열람 상태 필터 (READ / UNREAD)
    public let status: String

    /// Query Parameter Dictionary 변환
    public var toParameters: [String: Any] {
        [
            "cursorId": cursorId,
            "filterType": filterType,
            "organizationIds": organizationIds,
            "status": status
        ]
    }
}
