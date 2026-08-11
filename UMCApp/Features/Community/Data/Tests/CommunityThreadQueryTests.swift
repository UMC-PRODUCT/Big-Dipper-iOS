//
//  CommunityThreadQueryTests.swift
//  CommunityDataTests
//

import Foundation
import Moya
import Testing
@testable import CommunityData

@Suite("Query DTO — Router 가 실제로 전송하는 파라미터")
struct CommunityThreadQueryTests {

    @Test("검색어가 없으면 q 키 자체를 보내지 않는다")
    func omitsEmptyQuery() {
        let query = ThreadListQuery(filter: "all", query: nil, offset: 0, limit: 20)

        let parameters = query.toParameters

        #expect(parameters["q"] == nil)
        #expect(parameters["filter"] as? String == "all")
        #expect(parameters["offset"] as? Int == 0)
        #expect(parameters["limit"] as? Int == 20)
    }

    @Test("검색어가 있으면 q 를 그대로 싣는다")
    func includesQuery() {
        let query = ThreadListQuery(filter: "STUDY", query: "iOS", offset: 40, limit: 20)

        #expect(query.toParameters["q"] as? String == "iOS")
        #expect(query.toParameters["offset"] as? Int == 40)
    }

    @Test("before 커서가 없으면 키를 보내지 않는다 — 최신부터 조회")
    func omitsNilCursor() {
        #expect(ThreadMessageQuery(before: nil, limit: 30).toParameters["before"] == nil)
    }

    @Test("before 커서가 있으면 문자열 그대로 싣는다")
    func includesCursor() {
        #expect(ThreadMessageQuery(before: "1024", limit: 30).toParameters["before"] as? String
            == "1024")
    }

    @Test("고정 설정/해제는 같은 경로에 POST/DELETE 로 갈린다")
    func pinPathAndMethod() {
        let on = CommunityThreadRouter.setPin(threadId: "7", isPinned: true)
        let off = CommunityThreadRouter.setPin(threadId: "7", isPinned: false)

        #expect(on.path == "/api/v1/community/threads/7/pin")
        #expect(off.path == "/api/v1/community/threads/7/pin")
        #expect(on.method == .post)
        #expect(off.method == .delete)
    }

    @Test("메시지 히스토리 경로는 스레드 하위다")
    func messagesPath() {
        let target = CommunityThreadRouter.getMessages(
            threadId: "7",
            query: ThreadMessageQuery(before: nil, limit: 30)
        )

        #expect(target.path == "/api/v1/community/threads/7/messages")
        #expect(target.method == .get)
    }
}

// MARK: - Suite: Router path/method/task 계약

@Suite("CommunityThreadRouter — path/method/task 계약")
struct CommunityThreadRouterContractTests {

    @Test("나머지 케이스의 path/method")
    func remainingPathsAndMethods() {
        let list = CommunityThreadRouter.getThreads(
            query: ThreadListQuery(filter: "all", query: nil, offset: 0, limit: 20)
        )
        let detail = CommunityThreadRouter.getThread(threadId: "7")
        let mute = CommunityThreadRouter.setMute(threadId: "7", isMuted: true)
        let unmute = CommunityThreadRouter.setMute(threadId: "7", isMuted: false)
        let leave = CommunityThreadRouter.leave(threadId: "7")

        #expect(list.path == "/api/v1/community/threads")
        #expect(detail.path == "/api/v1/community/threads/7")
        #expect(mute.path == "/api/v1/community/threads/7/mute")
        #expect(unmute.path == "/api/v1/community/threads/7/mute")
        #expect(leave.path == "/api/v1/community/threads/7/leave")

        #expect(list.method == .get)
        #expect(detail.method == .get)
        #expect(mute.method == .post)
        #expect(unmute.method == .delete)
        #expect(leave.method == .post)
    }

    @Test("목록 조회 task 는 Query DTO 파라미터를 쿼리스트링으로 싣는다")
    func threadListTaskCarriesQuery() {
        let target = CommunityThreadRouter.getThreads(
            query: ThreadListQuery(filter: "QNA", query: "면접", offset: 40, limit: 20)
        )

        guard case let .requestParameters(parameters, encoding) = target.task else {
            Issue.record("task 가 .requestParameters 여야 함 — 실제: \(target.task)")
            return
        }
        #expect(parameters["filter"] as? String == "QNA")
        #expect(parameters["q"] as? String == "면접")
        #expect(parameters["offset"] as? Int == 40)
        #expect(parameters["limit"] as? Int == 20)
        #expect((encoding as? URLEncoding)?.destination == URLEncoding.queryString.destination)
    }

    @Test("메시지 조회 task 는 before/limit 을 쿼리스트링으로 싣는다")
    func messageTaskCarriesQuery() {
        let target = CommunityThreadRouter.getMessages(
            threadId: "7",
            query: ThreadMessageQuery(before: "1024", limit: 30)
        )

        guard case let .requestParameters(parameters, encoding) = target.task else {
            Issue.record("task 가 .requestParameters 여야 함 — 실제: \(target.task)")
            return
        }
        #expect(parameters["before"] as? String == "1024")
        #expect(parameters["limit"] as? Int == 30)
        #expect((encoding as? URLEncoding)?.destination == URLEncoding.queryString.destination)
    }

    @Test("바디 없는 상태 변경 케이스는 .requestPlain")
    func plainTasks() {
        let targets: [CommunityThreadRouter] = [
            .getThread(threadId: "7"),
            .setPin(threadId: "7", isPinned: true),
            .setMute(threadId: "7", isMuted: false),
            .leave(threadId: "7")
        ]

        for target in targets {
            guard case .requestPlain = target.task else {
                Issue.record("task 가 .requestPlain 이어야 함 — 실제: \(target.task)")
                continue
            }
        }
    }
}
