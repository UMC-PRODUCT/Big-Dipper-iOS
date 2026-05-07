//
//  NoticeVoteResponseRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 공지 투표 응답(제출/수정) 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/votes/responses`
/// - `PUT /api/v1/notices/{noticeId}/votes/responses`
struct NoticeVoteResponseRequestDTO: Encodable {
    /// 사용자가 선택한 옵션 ID 목록
    let optionIds: [Int]
}
