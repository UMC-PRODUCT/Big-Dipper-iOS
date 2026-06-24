//
//  NoticeLinksRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 링크 추가/수정 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/links`
/// - `PATCH /api/v1/notices/{noticeId}/links`
public struct NoticeLinksRequestDTO: Encodable {
    /// 첨부 링크 URL 목록
    public let links: [String]
}
