//
//  PointLog.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 페널티 카드가 표시하는 포인트 내역 한 건.
public struct PointLog: Identifiable, Equatable, Sendable {

    // MARK: - Property

    /// 서버에서 발급한 안정적인 포인트 식별자
    public let id: String
    public let reason: String
    /// 표시용 날짜 문자열 (예: "07.09")
    public let date: String
    public let point: Int
    /// 상벌점 여부 (`true`: 상점, `false`: 벌점)
    public let isReward: Bool

    // MARK: - Init

    public init(id: String, reason: String, date: String, point: Int, isReward: Bool) {
        self.id = id
        self.reason = reason
        self.date = date
        self.point = point
        self.isReward = isReward
    }
}
