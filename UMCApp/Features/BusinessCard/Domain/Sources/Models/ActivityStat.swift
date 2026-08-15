//
//  ActivityStat.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 마이페이지 행 우측 숫자 묶음 (MP-F05·F07~F09).
///
/// 서버 유래 카운트라 전부 String (절대규칙 #2). 조회 실패한 소스는 "0"으로 채운다
/// (MP-F07 "값 없으면 0 표기 — 우측 값 일관"). 폴백은 UseCase 정책이다.
public struct ActivityStat: Equatable, Sendable {

    // MARK: - Property

    public let receivedCardCount: String
    public let studyCount: String
    public let activityCount: String
    public let bookmarkCount: String

    // MARK: - Init

    public init(
        receivedCardCount: String,
        studyCount: String,
        activityCount: String,
        bookmarkCount: String
    ) {
        self.receivedCardCount = receivedCardCount
        self.studyCount = studyCount
        self.activityCount = activityCount
        self.bookmarkCount = bookmarkCount
    }

    /// 전 소스 실패·미조회 상태.
    public static let empty = ActivityStat(
        receivedCardCount: "0", studyCount: "0", activityCount: "0", bookmarkCount: "0"
    )
}
