//
//  StompFrameTests.swift
//  CoreNetworkTests
//

import Foundation
import Testing
@testable import CoreNetwork

@Suite("StompFrame — STOMP 1.2 프레임 인코딩/디코딩")
struct StompFrameTests {

    @Test("SEND 프레임은 COMMAND, 헤더, 빈 줄, 본문, NULL 순으로 직렬화된다")
    func encodesSendFrame() throws {
        let frame = StompFrame(
            command: .send,
            headers: ["destination": "/app/threads/1/messages"],
            body: Data(#"{"content":"hi"}"#.utf8)
        )

        let encoded = try #require(String(data: frame.encoded(), encoding: .utf8))

        let expected = "SEND\ndestination:/app/threads/1/messages\n\n{\"content\":\"hi\"}\u{00}"
        #expect(encoded == expected)
    }

    @Test("헤더 값의 콜론·개행·백슬래시는 이스케이프된다")
    func escapesHeaderValue() throws {
        let frame = StompFrame(command: .send, headers: ["k": "a:b\nc\\d"], body: Data())

        let encoded = try #require(String(data: frame.encoded(), encoding: .utf8))

        #expect(encoded.contains("k:a\\cb\\nc\\\\d"))
    }

    @Test("MESSAGE 프레임을 디코딩하면 커맨드·헤더·본문이 복원된다")
    func decodesMessageFrame() throws {
        let raw = Data("MESSAGE\nsubscription:sub-0\nmessage-id:7\n\n{\"a\":1}\u{00}".utf8)

        let frame = try #require(try StompFrame.decode(raw))

        #expect(frame.command == .message)
        #expect(frame.headers["subscription"] == "sub-0")
        #expect(frame.headers["message-id"] == "7")
        #expect(frame.bodyString == "{\"a\":1}")
    }

    @Test("이스케이프된 헤더 값은 디코딩 시 원복된다")
    func unescapesHeaderValue() throws {
        let raw = Data("MESSAGE\nk:a\\cb\\nc\\\\d\n\n\u{00}".utf8)

        let frame = try #require(try StompFrame.decode(raw))

        #expect(frame.headers["k"] == "a:b\nc\\d")
    }

    @Test("같은 헤더 키가 반복되면 첫 값이 유효하다")
    func firstHeaderWins() throws {
        let raw = Data("MESSAGE\nk:first\nk:second\n\n\u{00}".utf8)

        let frame = try #require(try StompFrame.decode(raw))

        #expect(frame.headers["k"] == "first")
    }

    @Test("heartbeat 프레임(EOL 단독)은 nil 로 디코딩된다")
    func decodesHeartbeatAsNil() throws {
        #expect(try StompFrame.decode(Data("\n".utf8)) == nil)
        #expect(try StompFrame.decode(Data("\r\n".utf8)) == nil)
        #expect(try StompFrame.decode(Data()) == nil)
    }

    @Test("NUL 종료자가 없는 버퍼는 잘린 프레임으로 보고 malformed 로 실패한다")
    func rejectsFrameWithoutNullTerminator() {
        #expect(throws: StompFrameError.malformed) {
            try StompFrame.decode(Data("MESSAGE\nfoo:bar\n\nbody".utf8))
        }
    }

    @Test("본문 끝의 개행은 인코딩·디코딩 왕복 후에도 보존된다")
    func preservesTrailingNewlineInBody() throws {
        let frame = StompFrame(
            command: .send,
            headers: ["destination": "/app/threads/1/messages"],
            body: Data("line1\nline2\n".utf8)
        )

        let decoded = try #require(try StompFrame.decode(frame.encoded()))

        #expect(decoded.bodyString == "line1\nline2\n")
    }

    @Test("NUL 로 종료된 빈 본문 프레임은 heartbeat 가 아니라 빈 본문으로 디코딩된다")
    func decodesEmptyBodyFrame() throws {
        let frame = try #require(try StompFrame.decode(Data("MESSAGE\n\n\u{00}".utf8)))

        #expect(frame.command == .message)
        #expect(frame.body.isEmpty)
    }

    @Test("CONNECT 프레임의 헤더는 이스케이프·언이스케이프를 면제받는다")
    func skipsEscapingForConnectFrame() throws {
        let frame = StompFrame(command: .connect, headers: ["host": "a:b\\c"], body: Data())

        let encoded = try #require(String(data: frame.encoded(), encoding: .utf8))
        #expect(encoded == "CONNECT\nhost:a:b\\c\n\n\u{00}")

        let decoded = try #require(try StompFrame.decode(Data(encoded.utf8)))
        #expect(decoded.headers["host"] == "a:b\\c")
    }

    @Test("알 수 없는 커맨드는 unknownCommand 로 실패한다")
    func rejectsUnknownCommand() {
        #expect(throws: StompFrameError.self) {
            try StompFrame.decode(Data("BOGUS\n\n\u{00}".utf8))
        }
    }
}
