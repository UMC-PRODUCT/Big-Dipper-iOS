//
//  OperatorMemberPenaltyHistory.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation
import UMCFoundation

/// 운영진 멤버 관리 히스토리
///
/// 멤버 상벌점 히스토리를 나타내는 모델입니다.
public struct OperatorMemberPenaltyHistory: Identifiable, Equatable {

    // MARK: - Property

    /// 고유 식별자 (클라이언트 생성)
    public let id: UUID

    /// 서버 포인트 식별자 (서버 응답)
    public let challengerPointId: String?

    /// 날짜
    public let date: Date

    /// 사유
    public let reason: String

    /// 포인트 점수의 절대값 (부호 없음)
    ///
    /// 상점/벌점 구분은 이 값의 부호가 아니라 ``pointType`` 의 ``ChallengerPointType/isReward`` 로만 판별합니다.
    /// 따라서 항상 0 이상의 절대값을 보관합니다.
    public let penaltyScore: Double

    /// 포인트 유형
    public let pointType: ChallengerPointType

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        challengerPointId: String? = nil,
        date: Date,
        reason: String,
        penaltyScore: Double,
        pointType: ChallengerPointType
    ) {
        self.id = id
        self.challengerPointId = challengerPointId
        self.date = date
        self.reason = reason
        self.penaltyScore = penaltyScore
        self.pointType = pointType
    }
}
