//
//  CommunityThreadRoomViewTests.swift
//  CommunityPresentationTests
//

import Foundation
import SwiftUI
import Testing
import CommunityDomain
@testable import CommunityPresentation

// MARK: - Fixture

/// 실행 시각과 무관하게 같은 날짜를 만든다. 자정 근처에 테스트를 돌려도 결과가 흔들리지 않게
/// 구성과 비교가 같은 `Calendar.current` 를 쓴다.
private func makeDate(day: Int, hour: Int, minute: Int = 0) throws -> Date {
    let components = DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
    return try #require(Calendar.current.date(from: components))
}

private func makeMessage(id: String, createdAt: Date = Date()) -> ThreadMessage {
    ThreadMessage(
        id: id,
        threadId: "1",
        senderId: "7",
        senderName: "김유엠",
        content: "안녕하세요",
        type: .text,
        createdAt: createdAt
    )
}

// MARK: - Tests

/// 날짜 구분선 삽입 규칙.
///
/// 화면 자체는 자동화하지 않는다(스펙 §8). 대신 렌더링과 무관하게 틀릴 수 있는 규칙만
/// 순수 함수로 떼어 잠근다 — 구분선이 빠지거나 매 행마다 붙는 건 눈으로도 늦게 발견된다.
@Suite("CommunityThreadRoomView.dividerDate")
struct CommunityThreadRoomViewTests {

    @Test("첫 메시지 앞에는 항상 구분선을 넣는다")
    func insertsDividerBeforeFirstMessage() throws {
        let first = try makeDate(day: 11, hour: 9)
        let messages = [makeMessage(id: "1", createdAt: first)]

        #expect(CommunityThreadRoomView.dividerDate(at: 0, in: messages) == first)
    }

    @Test("같은 날 메시지 사이에는 구분선을 넣지 않는다")
    func skipsDividerWithinSameDay() throws {
        let messages = [
            makeMessage(id: "1", createdAt: try makeDate(day: 11, hour: 9)),
            makeMessage(id: "2", createdAt: try makeDate(day: 11, hour: 23, minute: 59))
        ]

        #expect(CommunityThreadRoomView.dividerDate(at: 1, in: messages) == nil)
    }

    @Test("날짜가 바뀌면 구분선을 넣는다")
    func insertsDividerOnDayChange() throws {
        let secondDay = try makeDate(day: 12, hour: 9)
        let messages = [
            makeMessage(id: "1", createdAt: try makeDate(day: 11, hour: 9)),
            makeMessage(id: "2", createdAt: secondDay)
        ]

        #expect(CommunityThreadRoomView.dividerDate(at: 1, in: messages) == secondDay)
    }

    /// 경과 시간(24시간)이 아니라 캘린더 날짜로 판정해야 한다. 2분 차이라도 날짜가 넘어갔으면
    /// 구분선이 필요하다.
    @Test("자정을 넘기면 2분 차이여도 구분선을 넣는다")
    func insertsDividerAcrossMidnight() throws {
        let afterMidnight = try makeDate(day: 12, hour: 0, minute: 1)
        let messages = [
            makeMessage(id: "1", createdAt: try makeDate(day: 11, hour: 23, minute: 59)),
            makeMessage(id: "2", createdAt: afterMidnight)
        ]

        #expect(CommunityThreadRoomView.dividerDate(at: 1, in: messages) == afterMidnight)
    }

    /// 실시간 이벤트로 배열이 줄어드는 순간에도 `ForEach` 의 인덱스로 조회한다.
    @Test("범위를 벗어난 인덱스는 nil 을 준다")
    func returnsNilForOutOfRangeIndex() throws {
        let messages = [makeMessage(id: "1", createdAt: try makeDate(day: 11, hour: 9))]

        #expect(CommunityThreadRoomView.dividerDate(at: 1, in: messages) == nil)
        #expect(CommunityThreadRoomView.dividerDate(at: -1, in: messages) == nil)
        #expect(CommunityThreadRoomView.dividerDate(at: 0, in: []) == nil)
    }
}

/// 읽음 워터마크 게이팅 (스펙 6.4).
///
/// ViewModel 의 `markRead(upTo:)` 는 무조건 보낸다 — "언제 보낼지" 는 전적으로 화면의 판단이라
/// 여기서만 잠글 수 있다. 조건이 새면 안 본 메시지까지 읽음 처리된다.
@Suite("CommunityThreadRoomView.readableMessageId")
struct CommunityThreadRoomWatermarkTests {

    @Test("백그라운드에서는 워터마크를 올리지 않는다")
    func skipsWatermarkWhenNotActive() {
        let messages = [makeMessage(id: "1"), makeMessage(id: "2")]

        #expect(CommunityThreadRoomView.readableMessageId(
            scenePhase: .background, isNearBottom: true, messages: messages
        ) == nil)
        #expect(CommunityThreadRoomView.readableMessageId(
            scenePhase: .inactive, isNearBottom: true, messages: messages
        ) == nil)
    }

    @Test("과거를 올려다보는 중에는 워터마크를 올리지 않는다")
    func skipsWatermarkWhenScrolledUp() {
        let messages = [makeMessage(id: "1"), makeMessage(id: "2")]

        #expect(CommunityThreadRoomView.readableMessageId(
            scenePhase: .active, isNearBottom: false, messages: messages
        ) == nil)
    }

    @Test("포그라운드 + 최하단이면 마지막 메시지로 워터마크를 올린다")
    func reportsLastMessageWhenActiveAtBottom() {
        let messages = [makeMessage(id: "1"), makeMessage(id: "2")]

        #expect(CommunityThreadRoomView.readableMessageId(
            scenePhase: .active, isNearBottom: true, messages: messages
        ) == "2")
        #expect(CommunityThreadRoomView.readableMessageId(
            scenePhase: .active, isNearBottom: true, messages: []
        ) == nil)
    }
}
