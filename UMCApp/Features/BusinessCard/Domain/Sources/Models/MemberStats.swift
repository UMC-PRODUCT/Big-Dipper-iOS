//
//  MemberStats.swift
//  BusinessCardDomain
//
//  Created by JEONG on 8/30/26.
//

import Foundation

/// 마이페이지 통합 카운트 (`GET /api/v2/member/me/stats`).
///
/// 필드별 `nil` 은 **「못 셌다」**다 — 「0개다」와 다르다. 조회 실패를 `"0"` 으로 눌러
/// 담으면 통신이 끊긴 화면이 「스터디 0건」이라고 단언한다 (#1222).
///
/// 서버 정수는 전 레이어 `String` 이다 (절대 규칙 #2). 잘림 표기(`"50+"`)처럼 숫자가
/// 아닌 값도 그대로 나른다.
public struct MemberStats: Equatable, Sendable {

    // MARK: - Property

    public let receivedCardCount: String?
    public let studyCount: String?
    public let bookmarkCount: String?

    // MARK: - Init

    public init(receivedCardCount: String?, studyCount: String?, bookmarkCount: String?) {
        self.receivedCardCount = receivedCardCount
        self.studyCount = studyCount
        self.bookmarkCount = bookmarkCount
    }

    // MARK: - Static

    /// 아무것도 세지 못한 상태.
    public static let unavailable = MemberStats(
        receivedCardCount: nil, studyCount: nil, bookmarkCount: nil
    )
}
