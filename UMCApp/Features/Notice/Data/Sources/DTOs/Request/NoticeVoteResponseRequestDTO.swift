//
//  NoticeVoteResponseRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 투표 응답(제출/수정) 요청 DTO
///
/// - `POST /api/v1/notices/{noticeId}/votes/responses`
/// - `PUT /api/v1/notices/{noticeId}/votes/responses`
public struct NoticeVoteResponseRequestDTO: Encodable {
    /// 사용자가 선택한 옵션 ID 목록
    public let optionIds: [String]
}
