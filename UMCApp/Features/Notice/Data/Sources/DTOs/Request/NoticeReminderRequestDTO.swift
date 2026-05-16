//
//  NoticeReminderRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

/// 공지 리마인더 발송 요청 DTO
///
/// `POST /api/v1/notices/{noticeId}/reminders`
public struct NoticeReminderRequestDTO: Encodable {
    /// 알림을 다시 보낼 대상 멤버 ID 목록
    public let targetIds: [Int]
}
