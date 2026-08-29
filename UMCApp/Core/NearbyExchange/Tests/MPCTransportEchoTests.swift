//
//  MPCTransportEchoTests.swift
//  CoreNearbyExchangeTests
//
//  Created by JEONG on 8/28/26.
//

import Foundation
import MultipeerConnectivity
import Testing
@testable import CoreNearbyExchange

/// 맞교환 회신의 **연결당 1회** 제한.
///
/// 양쪽이 동시에 광고하고 탐색하는 세션 모델이라, 명함을 받으면 자동으로 내 명함을 되돌려
/// 보낸다. 그 회신을 받은 쪽이 또 회신하면 A→B→A→B 로 **무한 에코**가 된다.
/// `repliedSessionIDs` 가 그걸 막는데, 빠져도 컴파일은 되고 2대 검증에서도 "빨리 오간다"
/// 정도로만 보여 놓치기 쉽다.
///
/// ## 회신 시도를 어떻게 세는가
///
/// 회신은 `session.send(_:toPeers:with:)` 로 나간다. 테스트가 넘기는 프로브 세션에는
/// 연결된 피어가 없으므로 그 호출은 반드시 실패하고, 실패는 진단 로그에 `[send]` 로 남는다.
/// 즉 **`[send]` 로그 줄 수 = 회신을 시도한 횟수**다. 전송 자체를 가로챌 seam 이 없어
/// (프로덕션 코드를 고치지 않는다는 전제) 이 로그가 유일한 관측 채널이다.
///
/// 로그는 세션을 다시 열어도 지워지지 않으므로, 시점 간 **증분**으로 센다.
@Suite("MPCTransport — 맞교환 1회 제한(무한 에코 차단)")
struct MPCTransportEchoTests {

    // MARK: - Fixture

    private func makeCard(cardID: String) throws -> ExchangePayload {
        try ExchangePayload(
            cardID: cardID,
            name: "정의찬",
            nickname: "제옹",
            part: "IOS",
            generation: "12",
            university: "한양대학교",
            email: nil,
            github: nil,
            linkedIn: nil,
            blog: nil,
            avatarURL: nil,
            cardLink: "umc://card/42",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func encodedCard(cardID: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(NearbyMessage.card(try makeCard(cardID: cardID)))
    }

    /// 델리게이트 인자로만 쓰이는 세션. 연결된 피어가 없어 회신 전송은 항상 실패한다.
    private func makeProbeSession() -> MCSession {
        MCSession(
            peer: MCPeerID(displayName: "probe-session"),
            securityIdentity: nil,
            encryptionPreference: .required
        )
    }

    private func makeProbeBrowser() -> MCNearbyServiceBrowser {
        MCNearbyServiceBrowser(
            peer: MCPeerID(displayName: "probe-browser"),
            serviceType: MPCTransport.serviceType
        )
    }

    /// 지금까지 나간 회신 시도 횟수 (누적).
    private func replyAttempts(_ transport: MPCTransport) -> Int {
        transport.diagnosticLog.filter { $0.contains("[send]") }.count
    }

    /// 지금까지 도착한 명함 수 (누적).
    /// 「도착은 했는데 회신을 안 했다」와 「애초에 도착하지 않았다」를 가른다.
    private func receivedCount(_ transport: MPCTransport) -> Int {
        transport.diagnosticLog.filter { $0.hasPrefix("명함 수신") }.count
    }

    // MARK: - Test

    @Test("같은 피어가 명함을 두 번 보내도 회신은 한 번만 나간다")
    func repliesOncePerPeer() async throws {
        let transport = MPCTransport()
        try await transport.startAdvertising(card: try makeCard(cardID: "MINE"))
        let probe = makeProbeSession()
        let peer = MCPeerID(displayName: "aaaa11112222")
        let data = try encodedCard(cardID: "THEIRS")

        transport.session(probe, didReceive: data, fromPeer: peer)
        let afterFirst = replyAttempts(transport)
        transport.session(probe, didReceive: data, fromPeer: peer)
        let afterSecond = replyAttempts(transport)

        #expect(receivedCount(transport) == 2, "두 장 모두 도착했어야 비교가 성립한다")
        #expect(afterFirst == 1, "첫 명함에는 내 명함으로 답해야 교환이 성립한다")
        #expect(
            afterSecond == 1,
            "두 번째 회신이 나가면 상대도 또 회신해 A→B→A→B 무한 에코가 된다"
        )

        await transport.stopAdvertising()
    }

    @Test("서로 다른 피어에게는 각각 회신한다 — 제한은 피어별이다")
    func repliesToEachPeerSeparately() async throws {
        let transport = MPCTransport()
        try await transport.startAdvertising(card: try makeCard(cardID: "MINE"))
        let probe = makeProbeSession()
        let data = try encodedCard(cardID: "THEIRS")

        transport.session(probe, didReceive: data, fromPeer: MCPeerID(displayName: "aaaa11112222"))
        transport.session(probe, didReceive: data, fromPeer: MCPeerID(displayName: "bbbb33334444"))

        #expect(
            replyAttempts(transport) == 2,
            "피어 하나가 회신을 받았다고 다른 피어까지 막으면 교환이 한 명하고만 된다"
        )

        await transport.stopAdvertising()
    }

    @Test("피어가 사라졌다 다시 나타나면 회신 자격도 되살아난다")
    func lostPeerCanExchangeAgain() async throws {
        let transport = MPCTransport()
        try await transport.startAdvertising(card: try makeCard(cardID: "MINE"))
        let probe = makeProbeSession()
        let peer = MCPeerID(displayName: "aaaa11112222")
        let data = try encodedCard(cardID: "THEIRS")

        transport.session(probe, didReceive: data, fromPeer: peer)
        transport.browser(makeProbeBrowser(), lostPeer: peer)
        transport.session(probe, didReceive: data, fromPeer: peer)

        #expect(
            replyAttempts(transport) == 2,
            "자리를 떴다 돌아온 상대와 다시 교환할 수 없으면 앱을 껐다 켜야 한다"
        )

        await transport.stopAdvertising()
    }

    @Test("세션을 다시 열면 회신 기록이 초기화된다 — 인스턴스가 앱 수명 싱글톤이다")
    func restartingSessionClearsReplyHistory() async throws {
        let transport = MPCTransport()
        let peer = MCPeerID(displayName: "aaaa11112222")
        let data = try encodedCard(cardID: "THEIRS")

        try await transport.startAdvertising(card: try makeCard(cardID: "MINE"))
        transport.session(makeProbeSession(), didReceive: data, fromPeer: peer)
        await transport.stopAdvertising()
        let beforeRestart = replyAttempts(transport)

        try await transport.startAdvertising(card: try makeCard(cardID: "MINE"))
        transport.session(makeProbeSession(), didReceive: data, fromPeer: peer)

        #expect(
            replyAttempts(transport) - beforeRestart == 1,
            "새 세션인데 옛 기록이 남으면 두 번째 교환에서 내 명함이 나가지 않는다"
        )

        await transport.stopAdvertising()
    }
}
