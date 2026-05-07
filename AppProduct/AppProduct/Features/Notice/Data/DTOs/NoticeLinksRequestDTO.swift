//
//  NoticeLinksRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import Foundation

/// 공지 링크 추가/수정 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/links`
/// - `PATCH /api/v1/notices/{noticeId}/links`
struct NoticeLinksRequestDTO: Encodable {
    /// 첨부 링크 URL 목록
    let links: [String]
}
