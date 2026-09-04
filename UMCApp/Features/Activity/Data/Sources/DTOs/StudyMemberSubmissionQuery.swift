//
//  StudyMemberSubmissionQuery.swift
//  ActivityData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 스터디원 제출 현황 조회 Query DTO
///
/// `GET /api/v2/curriculums/workbook-submissions`
///
/// 라우터 `task` 에 인라인 딕셔너리를 두지 않도록 쿼리 파라미터를 캡슐화합니다(핵심 규칙 #6).
///
/// 서버는 네 파라미터를 모두 선택으로 받으므로, 값이 없는 필터는 **키 자체를 보내지 않습니다**
/// (빈 문자열이나 빈 배열을 보내면 서버 `@Positive` 검증에 걸리거나 필터가 잘못 적용됨).
///
/// - Note: 식별자·주차는 서버 응답이라 전 레이어 `String` 입니다(핵심 규칙 #2). 쿼리 문자열은
///   와이어에서 어차피 텍스트라 서버의 `Long` 바인딩과 충돌하지 않습니다. `size` 만 클라이언트
///   페이지네이션 수치라 `Int` 입니다.
struct StudyMemberSubmissionQuery: Sendable, Equatable {

    // MARK: - Property

    /// 특정 스터디 그룹만 조회 (`nil` 이면 요청자가 관리 가능한 전체 그룹)
    let studyGroupId: String?
    /// 조회할 주차 번호 목록 (비어 있으면 전체 주차)
    let weekNos: [String]
    /// 직전 페이지 마지막 `studyGroupMemberId` (첫 페이지는 `nil`)
    let cursor: String?
    /// 페이지 크기 (스터디원 기준, 서버 최대 100)
    let size: Int

    // MARK: - Init

    init(
        studyGroupId: String? = nil,
        weekNos: [String] = [],
        cursor: String? = nil,
        size: Int
    ) {
        self.studyGroupId = studyGroupId
        self.weekNos = weekNos
        self.cursor = cursor
        self.size = size
    }

    // MARK: - Parameters

    /// Query Parameter Dictionary 변환. 값이 없는 필터는 키를 생략한다.
    var toParameters: [String: Any] {
        var parameters: [String: Any] = ["size": size]

        if let studyGroupId, !studyGroupId.isEmpty {
            parameters["studyGroupId"] = studyGroupId
        }
        if !weekNos.isEmpty {
            parameters["weekNos"] = weekNos
        }
        if let cursor, !cursor.isEmpty {
            parameters["cursor"] = cursor
        }

        return parameters
    }
}
