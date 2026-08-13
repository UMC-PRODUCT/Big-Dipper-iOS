//
//  ThreadCommandBodyTests.swift
//  CommunityDataTests
//

import Foundation
import Testing
@testable import CommunityData

@Suite("STOMP SEND 본문과 destination")
struct ThreadCommandBodyTests {

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("메시지 본문은 항상 TEXT 타입으로 나간다 — 1차 PR 은 텍스트만 보낸다")
    func encodesTextMessage() throws {
        let body = SendMessageBody(
            clientMessageId: "aaaa-bbbb",
            content: "안녕",
            fileMetadataIds: []
        )

        let object = try json(body)
        #expect(object["type"] as? String == "TEXT")
        #expect(object["clientMessageId"] as? String == "aaaa-bbbb")
        #expect(object["content"] as? String == "안녕")
        #expect((object["fileMetadataIds"] as? [String])?.isEmpty == true)
    }

    @Test("읽음 본문은 워터마크 하나만 싣는다")
    func encodesReadWatermark() throws {
        let object = try json(ReadWatermarkBody(lastReadMessageId: "1024"))

        #expect(object["lastReadMessageId"] as? String == "1024")
        #expect(object.count == 1)
    }

    /// 서버가 `emoji` 외 필드를 보면 `@JsonAnySetter` 로 프레임을 통째로 거절한다.
    @Test("반응 본문은 이모지 하나만 싣는다")
    func encodesReactionEmojiOnly() throws {
        let object = try json(ReactionBody(emoji: "👍"))

        #expect(object["emoji"] as? String == "👍")
        #expect(object.count == 1)
    }

    @Test("삭제 본문은 빈 객체다 — 대상은 destination 이 지목한다")
    func encodesEmptyDeleteBody() throws {
        #expect(try json(EmptyCommandBody()).isEmpty)
    }

    @Test("destination 은 threadId 를 경로에 박는다")
    func buildsDestinations() {
        #expect(ThreadDestination.messages("12") == "/app/community/threads/12/messages")
        #expect(ThreadDestination.read("12") == "/app/community/threads/12/read")
        #expect(ThreadDestination.events == "/user/queue/community/threads/events")
        #expect(ThreadDestination.errors == "/user/queue/errors")
    }

    /// 반응은 토글 destination 이 없다 — add/remove 경로가 뒤바뀌면 카운트가 반대로 움직인다.
    @Test("반응·삭제 destination 은 messageId 까지 경로에 박는다")
    func buildsMessageScopedDestinations() {
        #expect(
            ThreadDestination.reactionAdd("12", "77")
                == "/app/community/threads/12/messages/77/reactions/add"
        )
        #expect(
            ThreadDestination.reactionRemove("12", "77")
                == "/app/community/threads/12/messages/77/reactions/remove"
        )
        #expect(
            ThreadDestination.deleteMessage("12", "77")
                == "/app/community/threads/12/messages/77/delete"
        )
    }

    @Test("x-command-id 는 canonical lowercase UUID 다 — 서버가 대문자를 거절한다")
    func generatesLowercaseCommandID() {
        let identifier = ThreadCommandID.generate()

        #expect(identifier == identifier.lowercased())
        #expect(UUID(uuidString: identifier) != nil)
    }
}
