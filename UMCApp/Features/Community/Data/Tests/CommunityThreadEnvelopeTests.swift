//
//  CommunityThreadEnvelopeTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
import CoreNetwork
import UMCFoundation
import CommunityDomain
@testable import CommunityData

/// Repository 가 실제로 하는 일(공통 envelope 벗기기 → `toDomain`)을 그대로 검증한다.
/// `MoyaNetworkAdapter` 는 테스트 번들에서 만들 수 없어 Repository 타입 자체는 직접 못 돌린다.
@Suite("스레드 응답 envelope 처리")
struct CommunityThreadEnvelopeTests {

    private func decode<T: Codable>(_ type: T.Type, _ json: String) throws -> APIResponse<T> {
        try JSONDecoder().decode(APIResponse<T>.self, from: Data(json.utf8))
    }

    @Test("envelope 을 벗겨 result 페이로드만 도메인으로 넘긴다")
    func unwrapsListEnvelope() throws {
        let json = """
        {
          "success": true, "code": "200", "message": "성공",
          "result": {
            "pinned": [{"threadId": "1", "title": "고정", "category": "STUDY",
                        "createdBy": "5", "createdAt": "2026-08-01T00:00:00Z",
                        "updatedAt": "2026-08-01T00:00:00Z"}],
            "threads": [{"threadId": "2", "title": "일반", "category": "FREE",
                         "createdBy": "9", "createdAt": "2026-08-01T00:00:00Z",
                         "updatedAt": "2026-08-01T00:00:00Z"}],
            "nextOffset": "20", "total": "31"
          }
        }
        """

        let page = try decode(CommunityThreadListDTO.self, json).unwrap().toDomain

        #expect(page.pinned.map(\.id) == ["1"])
        #expect(page.threads.map(\.id) == ["2"])
        #expect(page.nextOffset == "20")
        #expect(page.total == "31")
    }

    @Test("실패 envelope 은 serverError 로 바꾼다")
    func throwsServerErrorOnFailure() throws {
        let json = """
        {"success": false, "code": "THREAD404", "message": "존재하지 않는 스레드", "result": null}
        """

        let response = try decode(CommunityThreadDTO.self, json)

        #expect(throws: RepositoryError.serverError(code: "THREAD404", message: "존재하지 않는 스레드")) {
            _ = try response.unwrap()
        }
    }

    @Test("깨진 메시지가 버려져도 hasMore 는 서버 값을 그대로 쓴다")
    func keepsServerHasMore() throws {
        let json = """
        {
          "success": true, "code": "200", "message": "성공",
          "result": {
            "messages": [
              {"messageId": "9", "threadId": "1", "senderId": "5", "senderName": "정의진",
               "content": "안녕", "type": "TEXT", "createdAt": "2026-08-11T10:00:00Z"},
              {"threadId": "1", "content": "messageId 없는 깨진 원소"}
            ],
            "hasMore": true, "nextBefore": "9"
          }
        }
        """

        let page = try decode(ThreadMessagePageDTO.self, json).unwrap().toDomain

        #expect(page.messages.count == 1)
        #expect(page.hasMore)
        #expect(page.nextBefore == "9")
    }
}
