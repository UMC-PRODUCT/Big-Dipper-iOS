//
//  AITokenDailyUsageRecord.swift
//  NoticeDomain
//
//  Created by 이예지 on 7/14/26.
//

import Foundation
import SwiftData

/// AI 토큰 일일 사용량 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 멤버별 당일 AI 개선 기능 토큰 누적 사용량을 보존합니다.
/// 키는 (memberKey, date의 startOfDay) 조합으로 식별합니다.
@Model
public final class AITokenDailyUsageRecord {

    // MARK: - Property

    /// 사용량을 집계할 멤버 ID
    ///
    /// - Note: 레거시(v2.2.0)가 `memberId: Int`로 프로덕션 CloudKit 스키마에 배포해
    ///   `CD_memberId`가 Int64로 확정돼 있다. 배포된 필드는 타입을 바꿀 수 없으므로
    ///   `String` 통일(핵심 규칙 #2)은 새 필드(`CD_memberKey`)로 분리해 적용한다.
    public var memberKey: String = ""
    public var date: Date = Date()
    public var usedTokens: Int = 0

    // MARK: - Init

    public init(
        memberKey: String,
        date: Date,
        usedTokens: Int
    ) {
        self.memberKey = memberKey
        self.date = date
        self.usedTokens = usedTokens
    }
}
