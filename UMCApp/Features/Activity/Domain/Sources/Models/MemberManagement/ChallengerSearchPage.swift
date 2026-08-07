//
//  ChallengerSearchPage.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDomain
import Foundation

/// 챌린저 커서 검색 한 페이지
///
/// 스터디 그룹 생성·인원 추가 화면이 멘토/스터디원을 고를 때 쓰는 검색 결과입니다.
/// 항목 모델은 Core canonical ``CoreDomain/ChallengerInfo`` 를 그대로 사용합니다 —
/// 선택 결과가 그대로 `OperatorStudyManagementViewModel` 로 넘어가므로 feature 전용 모델을
/// 따로 두면 경계마다 변환이 생기고 `selectionKey` 규칙이 갈립니다.
public struct ChallengerSearchPage: Equatable {

    // MARK: - Property

    /// 현재 페이지의 챌린저 목록
    public let challengers: [ChallengerInfo]

    /// 다음 페이지 존재 여부
    public let hasNext: Bool

    /// 다음 페이지 조회용 커서.
    ///
    /// 서버가 `Long` 으로 내려주고 다음 요청에 그대로 돌려주는 페이지네이션 토큰이라 `Int?`
    /// 입니다(식별자를 `String` 으로 통일하는 규칙은 화면이 다루는 서버 식별자 대상).
    public let nextCursor: Int?

    // MARK: - Init

    public init(
        challengers: [ChallengerInfo],
        hasNext: Bool,
        nextCursor: Int?
    ) {
        self.challengers = challengers
        self.hasNext = hasNext
        self.nextCursor = nextCursor
    }
}
