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
    /// 상벌점 값. 서버가 `-0.5` 같은 소수 배점을 내려주므로 `Double`로 유지한다.
    ///
    /// 절대 규칙 #2(서버 응답 "정수"는 전 레이어 `String`)의 대상이 아니다. 원본
    /// ``ProfileChallengerPoint/point``가 `Double`이라 `String`으로 감싸면 합산·`abs`마다
    /// 파싱이 필요하고, 실패 시 값이 사라진다. 손실 없이 그대로 옮기는 쪽이 단순하고 안전하다.
    public let point: Double
    /// 상벌점 여부 (`true`: 상점, `false`: 벌점)
    public let isReward: Bool

    // MARK: - Init

    public init(id: String, reason: String, date: String, point: Double, isReward: Bool) {
        self.id = id
        self.reason = reason
        self.date = date
        self.point = point
        self.isReward = isReward
    }
}
