//
//  WatchMessengerTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/30/26.
//

#if canImport(WatchConnectivity)
import Foundation
import Testing
@testable import CoreWatchConnectivity

/// 지금 이 모듈에 존재하는 페이로드 계약은 `[String: Any]` 딕셔너리 전달뿐이다.
/// Codable 도메인 페이로드는 선행 이슈(#1205~#1215) 결과물이라 아직 develop에 없으므로,
/// 여기서는 "메신저가 딕셔너리를 손대지 않고 세션까지 그대로 옮긴다"는 계약만 고정한다.
@Suite("WatchMessenger — 딕셔너리 페이로드 전달 계약")
struct WatchMessengerTests {

    private func makeActivated() -> (WatchMessenger, FakeWatchSession) {
        let session = FakeWatchSession()
        session.isReachable = true
        let coordinator = WatchSessionCoordinator(session: session)
        coordinator.applyActivation(state: .activated, error: nil)
        return (WatchMessenger(coordinator: coordinator), session)
    }

    @Test("sendMessage는 페이로드를 변형 없이 세션으로 넘긴다")
    func sendMessageForwardsPayloadVerbatim() async throws {
        let (messenger, session) = makeActivated()

        try await messenger.sendMessage([
            "type": "attendanceCheck",
            "generation": "12",
            "count": 3,
        ])

        let sent = try #require(session.sentMessages.first)
        #expect(session.sentMessages.count == 1)
        #expect(sent["type"] as? String == "attendanceCheck")
        #expect(sent["generation"] as? String == "12")
        #expect(sent["count"] as? Int == 3)
    }

    @Test("updateApplicationContext는 컨텍스트를 변형 없이 세션으로 넘긴다")
    func updateContextForwardsPayloadVerbatim() throws {
        let (messenger, session) = makeActivated()

        try messenger.updateApplicationContext(["latestNoticeID": "88"])

        let context = try #require(session.appliedContexts.first)
        #expect(session.appliedContexts.count == 1)
        #expect(context["latestNoticeID"] as? String == "88")
    }

    @Test("코디네이터의 에러는 메신저를 통과해 그대로 올라온다")
    func errorsBubbleUpThroughMessenger() async {
        let session = FakeWatchSession()
        let coordinator = WatchSessionCoordinator(session: session)
        let messenger = WatchMessenger(coordinator: coordinator)

        await #expect(throws: WatchConnectivityError.sessionNotActivated) {
            try await messenger.sendMessage(["ping": true])
        }
    }
}
#endif
