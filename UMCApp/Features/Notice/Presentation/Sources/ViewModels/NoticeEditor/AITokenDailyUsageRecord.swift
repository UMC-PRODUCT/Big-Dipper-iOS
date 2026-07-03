//
//  AITokenDailyUsageRecord.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import SwiftData

/// AI 토큰 일일 사용량 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 멤버별 당일 AI 개선 기능 토큰 누적 사용량을 보존합니다.
/// 키는 (memberId, date의 startOfDay) 조합으로 식별합니다.
@Model
public final class AITokenDailyUsageRecord {

    // MARK: - Property

    public var memberId: String = ""
    public var date: Date = Date()
    public var usedTokens: Int = 0

    // MARK: - Init

    public init(
        memberId: String,
        date: Date,
        usedTokens: Int
    ) {
        self.memberId = memberId
        self.date = date
        self.usedTokens = usedTokens
    }
}
