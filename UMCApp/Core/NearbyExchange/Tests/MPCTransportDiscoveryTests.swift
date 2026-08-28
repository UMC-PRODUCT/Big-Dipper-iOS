//
//  MPCTransportDiscoveryTests.swift
//  CoreNearbyExchangeTests
//
//  Created by JEONG on 8/28/26.
//

import Foundation
import MultipeerConnectivity
import Testing
@testable import CoreNearbyExchange

/// 광고를 발견 행으로 옮기는 규칙과, 누가 초대를 보낼지 정하는 타이브레이크.
///
/// 두 가지 모두 **조용히 깨진다**. 결손 광고를 걸러내지 못하면 식별자 없는 유령 행이 목록에
/// 남고, 타이브레이크가 깨지면 양쪽이 서로를 동시에 초대해 같은 쌍에 두 연결이 포개져
/// **둘 다 실패한다**. 실기기에서 「첫 탭은 20초 만에 실패, 두 번째 탭은 성공」 으로
/// 나타났던 증상이 후자다.
@Suite("MPCTransport — 발견 광고 해석·초대 타이브레이크")
struct MPCTransportDiscoveryTests {

    // MARK: - Fixture

    private func makeCard() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-1",
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
            cardLink: "umc://card/42"
        )
    }

    private func makeProbeBrowser() -> MCNearbyServiceBrowser {
        MCNearbyServiceBrowser(
            peer: MCPeerID(displayName: "probe-browser"),
            serviceType: MPCTransport.serviceType
        )
    }

    private func makeProbeSession() -> MCSession {
        MCSession(
            peer: MCPeerID(displayName: "probe-session"),
            securityIdentity: nil,
            encryptionPreference: .required
        )
    }

    /// 광고를 하나 흘려보낸다. `foundPeer` 는 `MCPeerID.displayName` 을 세션 식별자로 읽으므로
    /// 광고의 `s` 와 같은 값을 쓴다 (프로덕션에서도 둘은 같은 값이다).
    private func feed(
        _ info: [String: String]?,
        peerID: String = "peer-id",
        to transport: MPCTransport
    ) {
        transport.browser(
            makeProbeBrowser(),
            foundPeer: MCPeerID(displayName: peerID),
            withDiscoveryInfo: info
        )
    }

    /// 이 실행의 내 세션 식별자. `localPeerDescription` 이 `"<기종> · <식별자>"` 형식이다.
    private func localSessionID(of transport: MPCTransport) throws -> String {
        try #require(transport.localPeerDescription.components(separatedBy: " · ").last)
    }

    // 세션 식별자는 UUID 에서 뽑은 **소문자 16진수 12자**다. 그래서 `!`(0x21) 로 시작하는
    // 문자열은 어떤 식별자보다 반드시 작고, `~`(0x7E) 로 시작하면 반드시 크다.
    private static let smallerPeerID = "!smaller-peer"
    private static let largerPeerID = "~larger-peer"

    // MARK: - 결손 광고 (makePeer)

    @Test("광고 정보가 아예 없으면 행을 만들지 않는다")
    func rejectsMissingDiscoveryInfo() {
        let transport = MPCTransport()

        feed(nil, to: transport)

        #expect(transport.discoveredPeerIDs.isEmpty)
    }

    @Test("세션 식별자가 없는 광고는 무시한다 — 식별자 없이는 피어를 구분할 수 없다")
    func rejectsAdvertisementWithoutSessionID() {
        let transport = MPCTransport()

        feed(["n": "정의찬", "k": "제옹"], to: transport)

        #expect(transport.discoveredPeerIDs.isEmpty)
    }

    @Test("세션 식별자가 빈 문자열인 광고도 무시한다")
    func rejectsEmptySessionID() {
        let transport = MPCTransport()

        feed(["s": "", "n": "정의찬"], to: transport)

        #expect(transport.discoveredPeerIDs.isEmpty)
    }

    @Test("세션 식별자만 있으면 이름이 없어도 행은 만든다 — 익명 행이 정상 상태다")
    func acceptsSessionIDOnlyAdvertisement() {
        let transport = MPCTransport()

        feed(["s": "abc123abc123"], peerID: "abc123abc123", to: transport)

        #expect(transport.discoveredPeerIDs == ["abc123abc123"])
    }

    @Test("같은 피어를 다시 발견해도 목록이 늘지 않는다")
    func rediscoveryDoesNotDuplicate() {
        let transport = MPCTransport()

        feed(["s": "abc123abc123", "n": "정의찬"], peerID: "abc123abc123", to: transport)
        feed(["s": "abc123abc123", "n": "정의찬"], peerID: "abc123abc123", to: transport)

        #expect(transport.discoveredPeerIDs.count == 1)
    }

    @Test("이름·닉네임이 모두 있으면 「이름/닉네임」 으로 합친다")
    func composesDisplayNameFromBothFields() async throws {
        let peer = try await firstScannedPeer(
            info: ["s": "abc123abc123", "n": "정의찬", "k": "제옹", "p": "IOS", "g": "12"],
            peerID: "abc123abc123"
        )

        #expect(peer?.displayName == "정의찬/제옹")
        #expect(peer?.part == "IOS")
        #expect(peer?.generation == "12")
    }

    @Test("닉네임이 비면 이름만 쓴다 — 「정의찬/」 같은 행이 나오면 안 된다")
    func fallsBackToNameWhenNicknameMissing() async throws {
        let onlyName = try await firstScannedPeer(
            info: ["s": "abc123abc123", "n": "정의찬"],
            peerID: "abc123abc123"
        )
        let emptyNickname = try await firstScannedPeer(
            info: ["s": "def456def456", "n": "정의찬", "k": ""],
            peerID: "def456def456"
        )

        #expect(onlyName?.displayName == "정의찬")
        #expect(emptyNickname?.displayName == "정의찬")
    }

    @Test("이름 없이 닉네임만 온 광고는 표시 이름을 비운다")
    func leavesDisplayNameEmptyWithoutName() async throws {
        let peer = try await firstScannedPeer(
            info: ["s": "abc123abc123", "k": "제옹"],
            peerID: "abc123abc123"
        )

        #expect(peer?.displayName == nil)
    }

    @Test("발견 시점에는 거리를 모른다 — 거리는 NI 가 따로 채운다")
    func discoveryCarriesNoDistance() async throws {
        let peer = try await firstScannedPeer(
            info: ["s": "abc123abc123", "n": "정의찬"],
            peerID: "abc123abc123"
        )

        #expect(peer?.distanceMeters == nil)
    }

    // MARK: - 초대 타이브레이크

    @Test("식별자가 작은 쪽이 초대를 맡는다 — 발견 로그가 그 판정을 남긴다")
    func discoveryLogRecordsWhoInvites() throws {
        let transport = MPCTransport()
        let local = try localSessionID(of: transport)

        feed(["s": Self.smallerPeerID], peerID: Self.smallerPeerID, to: transport)
        feed(["s": Self.largerPeerID], peerID: Self.largerPeerID, to: transport)

        let log = transport.diagnosticLog
        #expect(local > Self.smallerPeerID, "식별자는 소문자 16진수라 '!' 보다 크다")
        #expect(local < Self.largerPeerID, "식별자는 소문자 16진수라 '~' 보다 작다")
        #expect(
            log.contains { $0.hasPrefix("발견") && $0.contains(Self.smallerPeerID)
                && $0.contains("상대가 초대 담당") },
            "나보다 작은 상대는 그쪽이 초대를 맡는다"
        )
        #expect(
            log.contains { $0.hasPrefix("발견") && $0.contains(Self.largerPeerID)
                && !$0.contains("상대가 초대 담당") },
            "나보다 큰 상대는 내가 초대를 맡는다"
        )
    }

    @Test("초대는 식별자가 큰 피어에게만 나간다 — 양쪽이 동시에 초대하면 둘 다 실패한다")
    func invitesOnlyLargerPeer() async throws {
        let transport = MPCTransport()
        // 초대가 나가려면 세션(광고)과 브라우저(탐색)가 모두 살아 있어야 한다.
        try await transport.startAdvertising(card: try makeCard())
        // 스트림을 붙잡아 둔다. 버리면 `onTermination` 이 browser 를 비동기로 지워
        // 초대가 나가지 않는다.
        let scan = transport.startScanning()

        feed(["s": Self.smallerPeerID], peerID: Self.smallerPeerID, to: transport)
        feed(["s": Self.largerPeerID], peerID: Self.largerPeerID, to: transport)

        let invitations = transport.diagnosticLog.filter { $0.hasPrefix("초대 ") }
        #expect(
            invitations.contains { $0.contains(Self.largerPeerID) },
            "식별자가 큰 상대에게는 내가 초대를 보내야 연결이 성립한다"
        )
        #expect(
            !invitations.contains { $0.contains(Self.smallerPeerID) },
            "양쪽이 서로 초대하면 같은 쌍에 두 연결이 포개져 둘 다 실패한다"
        )

        withExtendedLifetime(scan) {}
        await transport.stopAdvertising()
    }

    @Test("이미 연결 시도 중인 피어는 다시 초대하지 않는다")
    func skipsPeerAlreadyConnecting() async throws {
        let transport = MPCTransport()
        try await transport.startAdvertising(card: try makeCard())
        // 스트림을 붙잡아 둔다. 버리면 `onTermination` 이 browser 를 비동기로 지워
        // 초대가 나가지 않는다.
        let scan = transport.startScanning()
        let peerID = MCPeerID(displayName: Self.largerPeerID)

        // MPC 가 연결 진행을 알린 상태. 여기서 또 초대하면 연결이 겹친다.
        transport.session(makeProbeSession(), peer: peerID, didChange: .connecting)
        feed(["s": Self.largerPeerID], peerID: Self.largerPeerID, to: transport)

        #expect(
            !transport.diagnosticLog.contains { $0.hasPrefix("초대 ") },
            "시도 중인 피어를 다시 초대하면 MPC 가 두 연결을 겹쳐 받고 둘 다 실패한다"
        )

        withExtendedLifetime(scan) {}
        await transport.stopAdvertising()
    }

    @Test("연결 실패로 떨어지면 재시도 대상으로 되돌아온다")
    func failedConnectionBecomesRetryable() async throws {
        let transport = MPCTransport()
        try await transport.startAdvertising(card: try makeCard())
        // 스트림을 붙잡아 둔다. 버리면 `onTermination` 이 browser 를 비동기로 지워
        // 초대가 나가지 않는다.
        let scan = transport.startScanning()
        let peerID = MCPeerID(displayName: Self.largerPeerID)

        transport.session(makeProbeSession(), peer: peerID, didChange: .connecting)
        transport.session(makeProbeSession(), peer: peerID, didChange: .notConnected)
        feed(["s": Self.largerPeerID], peerID: Self.largerPeerID, to: transport)

        #expect(
            transport.diagnosticLog.contains {
                $0.hasPrefix("초대 ") && $0.contains(Self.largerPeerID)
            },
            "시도 표식이 남으면 재시도 타이머가 그 피어를 영영 건너뛴다"
        )

        withExtendedLifetime(scan) {}
        await transport.stopAdvertising()
    }

    // MARK: - Private Function

    /// 탐색 스트림을 열고 광고 하나를 흘려 첫 행을 받는다.
    ///
    /// 세션(광고)을 열지 않으므로 초대는 나가지 않는다 — 발견 해석만 본다.
    /// 스트림을 연 **직후 동기적으로** 델리게이트를 부르므로, 브라우징 실패 콜백(비동기)이
    /// 사이에 끼어들 수 없고 `AsyncStream` 은 이미 쌓인 값을 스트림이 닫힌 뒤에도 내보낸다.
    private func firstScannedPeer(
        info: [String: String],
        peerID: String
    ) async throws -> DiscoveredPeer? {
        let transport = MPCTransport()
        let stream = transport.startScanning()
        feed(info, peerID: peerID, to: transport)

        var iterator = stream.makeAsyncIterator()
        return await withTaskGroup(of: DiscoveredPeer?.self) { group in
            group.addTask { await iterator.next() }
            group.addTask {
                // 값이 오지 않아도 스위트 전체가 멈추지 않게 하는 안전장치.
                try? await Task.sleep(for: .milliseconds(500))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
