//
//  HomeGeneration.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 기수별 상벌점 현황.
///
/// `UMCFoundation.Generation`(기수 값 자체를 나타내는 단순 모델)과 이름이 겹치지 않도록
/// `HomeGeneration`으로 명명한다.
public struct HomeGeneration: Identifiable, Equatable, Sendable {

    // MARK: - Property

    public var id: String { gisuId }

    public let gisuId: String
    public let gen: String
    /// ``PointLog/point`` 합계이므로 소수 배점을 잃지 않도록 `Double`로 유지한다.
    public let penaltyPoint: Double
    public let rewardPoint: Double
    public let pointLogs: [PointLog]

    // MARK: - Init

    public init(
        gisuId: String,
        gen: String,
        penaltyPoint: Double,
        rewardPoint: Double,
        pointLogs: [PointLog]
    ) {
        self.gisuId = gisuId
        self.gen = gen
        self.penaltyPoint = penaltyPoint
        self.rewardPoint = rewardPoint
        self.pointLogs = pointLogs
    }
}
