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

    @Test("통합 카운트는 GET /api/v2/member/me/stats — v1이 아니다")
    func memberStatsContract() throws {
        let router = BusinessCardRouter.getMemberStats

        #expect(router.path == "/api/v2/member/me/stats")
        #expect(router.method == .get)
        guard case .requestPlain = router.task else {
            Issue.record("requestPlain이 아님"); return
        }
    }

    /// 첫 페이지에 빈 커서를 실어 보내면 서버가 그것을 커서 값으로 파싱하려 든다.
    @Test("명함첩 조회는 GET /api/v1/cards/exchanges — 첫 페이지는 cursor 키가 없다")
    func cardExchangesContract() throws {
        let first = BusinessCardRouter.getCardExchanges(query: CardExchangePageQueryDTO())

        #expect(first.path == "/api/v1/cards/exchanges")
        #expect(first.method == .get)
        guard case .requestParameters(let parameters, let encoding) = first.task else {
            Issue.record("requestParameters가 아님"); return
        }
        #expect(parameters["size"] as? Int == 100)
        #expect(parameters["cursor"] == nil)
        #expect(encoding is URLEncoding)

        let next = BusinessCardRouter.getCardExchanges(
            query: CardExchangePageQueryDTO(cursor: "1024")
        )
        guard case .requestParameters(let nextParameters, _) = next.task else {
            Issue.record("requestParameters가 아님"); return
        }
        #expect(nextParameters["cursor"] as? String == "1024")
    }

    @Test("교환 생성은 POST /api/v1/cards/exchanges — nil 필드는 키 자체가 빠진다")
    func createCardExchangeContract() throws {
        let router = BusinessCardRouter.createCardExchange(
            body: CreateCardExchangeRequestDTO(
                cardMemberId: "42", source: "NEARBY", exchangedAt: "2026-08-30T01:02:03Z"
            )
        )

        #expect(router.path == "/api/v1/cards/exchanges")
        #expect(router.method == .post)
        guard case .requestJSONEncodable(let body) = router.task,
              let encodable = body as? CreateCardExchangeRequestDTO else {
            Issue.record("requestJSONEncodable이 아님"); return
        }
        let json = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(encodable)
        ) as? [String: Any]
        #expect(json?["cardMemberId"] as? String == "42")
        #expect(json?["source"] as? String == "NEARBY")
        #expect(json?.keys.contains("slug") == false)
    }

    @Test("교환 삭제는 DELETE /api/v1/cards/exchanges/{cardMemberId}")
    func deleteCardExchangeContract() throws {
        let router = BusinessCardRouter.deleteCardExchange(cardMemberId: "42")

        #expect(router.path == "/api/v1/cards/exchanges/42")
        #expect(router.method == .delete)
        guard case .requestPlain = router.task else {
            Issue.record("requestPlain이 아님"); return
        }
    }

    @Test("명함 단건 조회는 GET /api/v1/cards/members/{memberId}")
    func cardByMemberIdContract() throws {
        let router = BusinessCardRouter.getCardByMemberId(memberId: "42")

        #expect(router.path == "/api/v1/cards/members/42")
        #expect(router.method == .get)
    }
}
