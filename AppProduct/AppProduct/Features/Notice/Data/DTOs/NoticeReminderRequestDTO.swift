//
//  NoticeReminderRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 공지 리마인더 발송 요청 DTO
///
/// `POST /api/v1/notices/{noticeId}/reminders`
struct NoticeReminderRequestDTO: Encodable {
    /// 알림을 다시 보낼 대상 멤버 ID 목록
    let targetIds: [Int]
}
