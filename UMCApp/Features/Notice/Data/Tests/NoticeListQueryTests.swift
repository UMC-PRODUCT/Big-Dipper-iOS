//
//  NoticeListQueryTests.swift
//  NoticeDataTests
//
//  Created by JEONG on 8/7/26.
//

import Testing
@testable import NoticeData

// MARK: - NoticeListQueryTests
/// `NoticeListQuery.toParameters` 회귀 테스트.
///
/// `noticeTab`은 서버가 챌린저 공지/운영진 공지를 가르는 필수 파라미터라
/// 쿼리에서 빠지면 운영진 공지 화면이 조용히 챌린저 공지를 보여준다.
struct NoticeListQueryTests {

    private func makeQuery(noticeTab: String) -> NoticeListQuery {
        NoticeListQuery(
            gisuId: "7",
            chapterId: nil,
            schoolId: nil,
            part: nil,
            noticeTab: noticeTab,
            page: 0,
            size: 20,
            sort: ["createdAt,DESC"]
        )
    }

    @Test("toParameters — noticeTab이 쿼리 파라미터에 그대로 실린다")
    func noticeTabIsSent() {
        let params = makeQuery(noticeTab: "SCHOOL_CORE").toParameters

        #expect(params["noticeTab"] as? String == "SCHOOL_CORE")
        #expect(params["gisuId"] as? String == "7")
    }

    @Test("toParameters(addingKeyword:) — 검색 요청에도 noticeTab이 유지된다")
    func noticeTabSurvivesSearch() {
        let params = makeQuery(noticeTab: "CENTRAL_MEMBER")
            .toParameters(addingKeyword: "공지")

        #expect(params["noticeTab"] as? String == "CENTRAL_MEMBER")
        #expect(params["keyword"] as? String == "공지")
    }
}
