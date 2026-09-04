//
//  ChallengerSearchCursorQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 챌린저 커서 검색 Query DTO
///
/// `GET /api/v1/challenger/search/cursor`
///
/// 라우터 `task` 에 인라인 딕셔너리를 두지 않도록 쿼리 파라미터를 캡슐화합니다(핵심 규칙 #6).
///
/// - Note: `cursor` 는 서버 `SearchChallengerCursorRequest.cursor` 가 `Long` 이라 `Int?` 로
///   보냅니다. 응답 식별자를 `String` 으로 통일하는 핵심 규칙 #2 는 **응답** 한정이며,
///   Request/Query DTO 는 서버 계약 타입을 그대로 따릅니다(핵심 규칙 #3 예외).
/// - Note: `keyword` 는 이름·닉네임 통합 검색어입니다. 값이 없으면 파라미터에서 제외해
///   서버가 전체 검색으로 처리하게 둡니다.
struct ChallengerSearchCursorQuery: Sendable, Equatable {

    // MARK: - Constants

    /// 서버 기본값(20)보다 큰 한 화면 분량. 서버 상한은 50이라 그 이상은 잘립니다.
    static let defaultSize = 50

    // MARK: - Property

    /// 이전 페이지의 마지막 챌린저 ID (첫 페이지는 `nil`)
    let cursor: Int?

    /// 한 페이지에 조회할 항목 수
    let size: Int

    /// 이름 또는 닉네임 통합 검색 키워드
    let keyword: String?

    // MARK: - Init

    init(
        cursor: Int? = nil,
        size: Int = ChallengerSearchCursorQuery.defaultSize,
        keyword: String? = nil
    ) {
        self.cursor = cursor
        self.size = size
        self.keyword = keyword
    }

    // MARK: - Parameters

    /// Query Parameter Dictionary 변환.
    var toParameters: [String: Any] {
        var parameters: [String: Any] = ["size": size]
        if let cursor {
            parameters["cursor"] = cursor
        }
        if let keyword, !keyword.isEmpty {
            parameters["keyword"] = keyword
        }
        return parameters
    }
}
