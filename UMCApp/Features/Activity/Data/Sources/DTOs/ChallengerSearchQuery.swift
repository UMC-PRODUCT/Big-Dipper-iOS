//
//  ChallengerSearchQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation

/// 챌린저 오프셋 검색 Query DTO
///
/// `GET /api/v1/challenger/search/offset`
///
/// 라우터 `task` 에 인라인 딕셔너리를 두지 않도록 쿼리 파라미터를 캡슐화합니다(핵심 규칙 #6).
///
/// - Note: `page`/`size` 는 클라이언트 페이지네이션 수치라 `Int`, `schoolId` 는 서버 식별자라
///   `String` 입니다(핵심 규칙 #2).
struct ChallengerSearchQuery: Sendable, Equatable {

    // MARK: - Property

    let page: Int
    let size: Int
    let schoolId: String

    // MARK: - Init

    init(page: Int, size: Int, schoolId: String) {
        self.page = page
        self.size = size
        self.schoolId = schoolId
    }

    // MARK: - Parameters

    /// Query Parameter Dictionary 변환.
    var toParameters: [String: Any] {
        [
            "page": page,
            "size": size,
            "schoolId": schoolId
        ]
    }
}
