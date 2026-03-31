//
//  NoticeReadRecord.swift
//  AppProduct
//
//  Created by euijjang97 on 3/12/26.
//

import Foundation
import SwiftData

/// 공지 읽음 상태 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 서버 목록 응답에 읽음 여부가 없을 때, 현재 사용자가 읽은 공지 ID를
/// 계정별로 보존하기 위해 사용합니다.
@Model
final class NoticeReadRecord {

    // MARK: - Property

    /// 읽음 상태를 저장한 멤버 ID
    var memberId: Int = 0

    /// 읽은 공지의 서버 식별자
    var noticeId: String = ""

    /// 마지막 업데이트 시간
    var updatedAt: Date = Date()

    // MARK: - Init

    init(
        memberId: Int,
        noticeId: String,
        updatedAt: Date = Date()
    ) {
        self.memberId = memberId
        self.noticeId = noticeId
        self.updatedAt = updatedAt
    }
}
