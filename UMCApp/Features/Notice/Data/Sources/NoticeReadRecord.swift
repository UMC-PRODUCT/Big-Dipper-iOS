//
//  NoticeReadRecord.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftData

/// 공지 읽음 상태 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 서버 목록 응답에 읽음 여부가 없을 때, 현재 사용자가 읽은 공지 ID를
/// 계정별로 보존하기 위해 사용합니다.
@Model
public final class NoticeReadRecord {

    // MARK: - Property

    /// 읽음 상태를 저장한 멤버 ID
    public var memberId: String = "0"

    /// 읽은 공지의 서버 식별자
    public var noticeId: String = ""

    /// 마지막 업데이트 시간
    public var updatedAt: Date = Date()

    // MARK: - Init

    public init(
        memberId: String,
        noticeId: String,
        updatedAt: Date = Date()
    ) {
        self.memberId = memberId
        self.noticeId = noticeId
        self.updatedAt = updatedAt
    }
}
