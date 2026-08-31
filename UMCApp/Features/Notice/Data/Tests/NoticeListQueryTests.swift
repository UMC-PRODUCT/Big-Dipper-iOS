//
//  NoticeListQueryTests.swift
//  NoticeDataTests
//
//  Created by euijjang97 on 8/7/26.
//

import Testing
import Foundation
import UMCFoundation
import NoticeDomain
@testable import NoticeData

@Suite("NoticeListQuery — 쿼리 파라미터 직렬화 (Router가 실제로 전송하는 값)")
struct NoticeListQueryTests {

    // MARK: - Helper

    private func makeQuery(
        chapterId: String? = nil,
        schoolId: String? = nil,
        part: UMCPartType? = nil,
        noticeTab: String = ManagementTeam.challenger.rawValue,
        sort: [String] = ["createdAt,DESC"]
    ) -> NoticeListQuery {
        NoticeListQuery(
            gisuId: "7",
            chapterId: chapterId,
            schoolId: schoolId,
            part: part,
            noticeTab: noticeTab,
            page: 0,
            size: 20,
            sort: sort
        )
    }

    // MARK: - Required Parameters

    @Test("필수 파라미터(gisuId·noticeTab·page·size)는 항상 전송된다")
    func emitsRequiredParameters() {
        let params = makeQuery().toParameters

        #expect(params["gisuId"] as? String == "7")
        #expect(params["noticeTab"] as? String == "CHALLENGER")
        #expect(params["page"] as? Int == 0)
        #expect(params["size"] as? Int == 20)
    }

    /// `NoticeListQuery`에 필드를 추가하고 `toParameters` 갱신을 잊으면 서버로 값이 전달되지
    /// 않는다. 운영진 공지 탭(`noticeTab`)이 실제로 이 회귀를 겪었으므로 탭 값별로 고정한다.
    @Test(
        "운영진 공지 탭 값이 noticeTab 파라미터로 그대로 전송된다",
        arguments: StaffNoticeTab.allCases
    )
    func emitsStaffNoticeTabRawValue(_ tab: StaffNoticeTab) {
        let params = makeQuery(noticeTab: tab.rawValue).toParameters

        #expect(params["noticeTab"] as? String == tab.rawValue)
    }

    @Test("검색 파라미터에도 noticeTab이 유지된 채 keyword가 더해진다")
    func keepsNoticeTabWhenAddingKeyword() {
        let params = makeQuery(noticeTab: StaffNoticeTab.schoolCore.rawValue)
            .toParameters(addingKeyword: "정기모임")

        #expect(params["noticeTab"] as? String == "SCHOOL_CORE")
        #expect(params["keyword"] as? String == "정기모임")
    }

    // MARK: - Optional Parameters

    @Test("nil인 선택 파라미터는 쿼리에서 생략된다")
    func omitsNilOptionalParameters() {
        let params = makeQuery().toParameters

        #expect(params["chapterId"] == nil)
        #expect(params["schoolId"] == nil)
        #expect(params["part"] == nil)
    }

    @Test("값이 있는 선택 파라미터는 전송되고 part는 apiValue로 변환된다")
    func emitsPresentOptionalParameters() {
        let params = makeQuery(chapterId: "3", schoolId: "900", part: .front(type: .ios))
            .toParameters

        #expect(params["chapterId"] as? String == "3")
        #expect(params["schoolId"] as? String == "900")
        #expect(params["part"] as? String == UMCPartType.front(type: .ios).apiValue)
    }

    @Test("sort가 비어 있으면 파라미터에서 제외된다")
    func omitsEmptySort() {
        #expect(makeQuery(sort: []).toParameters["sort"] == nil)
        #expect(makeQuery().toParameters["sort"] as? [String] == ["createdAt,DESC"])
    }

    // MARK: - Domain → Query 변환

    @Test("NoticeListRequest의 noticeTab이 Query로 그대로 전달된다")
    func carriesNoticeTabFromDomainRequest() {
        let request = NoticeListRequest(
            gisuId: "7",
            chapterId: nil,
            schoolId: "900",
            part: nil,
            noticeTab: StaffNoticeTab.schoolPartLeader.rawValue,
            page: 1,
            size: 20,
            sort: ["createdAt,DESC"]
        )

        #expect(NoticeListQuery(from: request).toParameters["noticeTab"] as? String
                == "SCHOOL_PART_LEADER")
    }

    @Test("noticeTab을 생략한 요청은 CHALLENGER로 조회한다")
    func defaultsToChallengerTab() {
        let request = NoticeListRequest(
            gisuId: "7",
            chapterId: nil,
            schoolId: nil,
            part: nil,
            page: 0,
            size: 20,
            sort: []
        )

        #expect(NoticeListQuery(from: request).toParameters["noticeTab"] as? String == "CHALLENGER")
    }
}
