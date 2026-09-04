//
//  ActivityStat.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 마이페이지 행 우측 숫자 묶음 (MP-F05·F07~F09).
///
/// 서버 유래 카운트라 전부 String (핵심규칙 #2). **`nil` 은 「아직 못 세었다」** —
/// 조회 실패거나 조회 전이다. 예전에는 실패도 `"0"` 으로 채워서 통신이 끊긴 화면이
/// 「받은 명함 0장」이라고 단언했다 (#1222). 화면은 `nil` 을 "-" 로 그린다.
public struct ActivityStat: Equatable, Sendable {

    // MARK: - Property

    public let receivedCardCount: String?
    public let studyCount: String?
    public let activityCount: String?
    public let bookmarkCount: String?

    // MARK: - Init

    public init(
        receivedCardCount: String?,
        studyCount: String?,
        activityCount: String?,
        bookmarkCount: String?
    ) {
        self.receivedCardCount = receivedCardCount
        self.studyCount = studyCount
        self.activityCount = activityCount
        self.bookmarkCount = bookmarkCount
    }

    /// 아직 아무 소스도 조회하지 않은 상태.
    public static let empty = ActivityStat(
        receivedCardCount: nil, studyCount: nil, activityCount: nil, bookmarkCount: nil
    )
}
