//
//  SessionStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation

/// 운영진 세션 진행 상태
public enum OperatorSessionStatus: String, CaseIterable, Sendable {
    case beforeStart = "진행전"
    case inProgress = "진행중"
    case ended = "종료됨"

    // MARK: - Property

    public var displayText: String { rawValue }

    // MARK: - Factory Method

    /// 시작/종료 시간으로부터 현재 상태 계산
    public static func from(
        startTime: Date,
        endTime: Date,
        now: Date = Date()
    ) -> OperatorSessionStatus {
        if now < startTime {
            return .beforeStart
        } else if now >= startTime && now <= endTime {
            return .inProgress
        } else {
            return .ended
        }
    }
}
