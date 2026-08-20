//
//  BusinessCardRouterTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import Moya
@testable import BusinessCardData

@Suite("BusinessCardRouter — 카운트 엔드포인트 계약")
struct BusinessCardRouterTests {

    @Test("내 스터디 목록은 GET /api/v1/study-groups/managed")
    func studyGroupsContract() throws {
        let router = BusinessCardRouter.getMyStudyGroups(query: StudyCountQueryDTO(size: 50))

        #expect(router.path == "/api/v1/study-groups/managed")
        #expect(router.method == .get)
        guard case .requestParameters(let parameters, let encoding) = router.task else {
            Issue.record("requestParameters가 아님"); return
        }
        #expect(parameters["size"] as? Int == 50)
        #expect(encoding is URLEncoding)
    }

    @Test("스크랩 목록은 GET /api/v1/posts/scrapped — size 1로 totalElements만 취한다")
    func scrappedContract() throws {
        let router = BusinessCardRouter.getScrappedPosts(query: ScrappedCountQueryDTO())

        #expect(router.path == "/api/v1/posts/scrapped")
        #expect(router.method == .get)
        guard case .requestParameters(let parameters, _) = router.task else {
            Issue.record("requestParameters가 아님"); return
        }
        #expect(parameters["page"] as? Int == 0)
        #expect(parameters["size"] as? Int == 1)
    }
}
