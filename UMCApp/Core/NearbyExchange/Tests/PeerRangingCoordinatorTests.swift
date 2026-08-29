//
//  PeerRangingCoordinatorTests.swift
//  CoreNearbyExchangeTests
//
//  Created by JEONG on 8/28/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

/// 레인징 조율 계층의 상태 전이 — 시작·소실·종료.
///
/// **거리 갱신(`didUpdate`)은 여기서 다루지 않는다.** `NINearbyObject` 는 공개 이니셜라이저가
/// 없어 테스트가 만들 수 없고, UWB 실측은 시뮬레이터에서 아예 돌지 않는다. 대신 값이 **비는**
/// 전이(피어 소실·세션 종료)를 고정한다 — 옛 거리가 굳어 남으면 지금 가까이 있는 것처럼
/// 보이는, 화면에서 가장 티 나는 실패 모드가 그쪽이다.
///
/// 핸드셰이크 경로는 UWB 탑재 여부와 무관하게 성립하는 계약만 검사한다. 시뮬레이터에서는
/// `isSupported` 가 항상 `false` 라 토큰이 `nil` 이고, 실기기에서는 토큰이 실린다.
@Suite("PeerRangingCoordinator — 핸드셰이크·거리 스트림 전이")
struct PeerRangingCoordinatorTests {

    // MARK: - Fixture

    private func makePreview() -> PeerPreview {
        PeerPreview(
            name: "정의찬",
            nickname: "제옹",
            part: "IOS",
            generation: "12",
            avatarURL: "https://cdn.umc.it.kr/a.png"
        )
    }

    /// 스트림의 첫 값을 기다린다. 값이 없으면 스위트가 멈추지 않도록 시간으로 끊는다.
    private func firstDistance(
        from stream: AsyncStream<PeerDistance>,
        timeout: Duration = .milliseconds(500)
    ) async -> PeerDistance?? {
        var iterator = stream.makeAsyncIterator()
        return await withTaskGroup(of: PeerDistance??.self) { group in
            group.addTask { .some(await iterator.next()) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .none                                    // 아무 값도 오지 않았다
            }
            let first = await group.next() ?? .none
            group.cancelAll()
            return first
        }
    }

    // MARK: - 핸드셰이크 (시작)

    @Test("미리보기를 설정하기 전에는 핸드셰이크를 만들지 않는다")
    func noHandshakeBeforeStart() {
        let coordinator = PeerRangingCoordinator()

        #expect(coordinator.makeHandshake(forPeerID: "peer-1") == nil)
    }

    @Test("시작하면 핸드셰이크에 내 미리보기가 실린다")
    func handshakeCarriesPreview() throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())

        let handshake = try #require(coordinator.makeHandshake(forPeerID: "peer-1"))

        #expect(handshake.preview == makePreview())
        // UWB 미탑재 기기(시뮬레이터·아이패드)는 토큰 없이 미리보기만 보낸다.
        #expect((handshake.niToken != nil) == PeerRangingCoordinator.isSupported)
    }

    @Test("핸드셰이크에는 이메일·외부 링크가 없다 — 동의 전에 자동으로 오간다")
    func handshakeCarriesNoContactDetails() throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let handshake = try #require(coordinator.makeHandshake(forPeerID: "peer-1"))

        let json = try #require(String(data: try JSONEncoder().encode(handshake), encoding: .utf8))

        #expect(!json.contains("email"))
        #expect(!json.contains("github"))
        #expect(!json.contains("linkedIn"))
        #expect(!json.contains("blog"))
    }

    @Test("피어마다 새 핸드셰이크를 만든다 — 전역 토큰 하나를 뿌리면 레인징이 조용히 실패한다")
    func makesHandshakePerPeer() throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())

        let first = try #require(coordinator.makeHandshake(forPeerID: "peer-1"))
        let second = try #require(coordinator.makeHandshake(forPeerID: "peer-2"))

        #expect(first.preview == second.preview)
        if PeerRangingCoordinator.isSupported {
            #expect(first.niToken != second.niToken, "세션마다 토큰이 달라야 한다")
        }
    }

    @Test("UWB 미탑재 상대의 핸드셰이크는 조용히 넘긴다 — 실패가 아니라 정상 경로다")
    func ignoresHandshakeWithoutToken() {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())

        coordinator.didReceiveHandshake(
            NearbyHandshake(preview: makePreview(), niToken: nil),
            fromPeerID: "peer-1"
        )

        #expect(coordinator.lastError == nil, "정상 경로가 에러 기록을 더럽히면 진단이 흐려진다")
    }

    @Test("내 세션이 없는 피어의 핸드셰이크는 무시하고 사유를 남긴다")
    func recordsHandshakeFromUnknownPeer() throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())

        // `makeHandshake` 를 거치지 않은 피어 — 내 쪽 세션이 없어 상대 토큰을 쓸 데가 없다.
        coordinator.didReceiveHandshake(
            NearbyHandshake(preview: makePreview(), niToken: Data([0x01, 0x02])),
            fromPeerID: "unknown-peer"
        )

        let error = try #require(coordinator.lastError)
        #expect(error.contains("unknown-peer"))
    }

    // MARK: - 거리 스트림 (소실·종료)

    @Test("피어가 사라지면 거리를 비운다 — 옛 값이 남으면 지금 가까이 있는 것처럼 보인다")
    func lostPeerClearsDistance() async throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let stream = coordinator.distances()

        coordinator.didLosePeer("peer-1")

        let distance = try #require(await firstDistance(from: stream) ?? nil)
        #expect(distance.peerID == "peer-1")
        #expect(distance.meters == nil)
    }

    @Test("여러 피어가 사라져도 각자의 식별자로 구분해 흘린다")
    func lostPeersAreDistinguished() async throws {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let stream = coordinator.distances()

        coordinator.didLosePeer("peer-1")
        coordinator.didLosePeer("peer-2")

        var received: [String] = []
        for await distance in stream {
            received.append(distance.peerID)
            if received.count == 2 { break }
        }

        #expect(received == ["peer-1", "peer-2"])
    }

    @Test("stopAll 은 거리 스트림을 닫는다 — 소비자가 영구 대기하면 안 된다")
    func stopAllClosesStream() async {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let stream = coordinator.distances()

        coordinator.stopAll()

        // `nil` 로 끝났다 = 스트림이 닫혔다. 시간으로 끊겼다면 열려 있다는 뜻이다.
        let terminal = await firstDistance(from: stream)
        #expect(terminal != nil, "스트림이 안 닫히면 교환 화면을 떠난 뒤에도 태스크가 남는다")
        #expect((terminal ?? nil) == nil)
    }

    @Test("세션을 다시 시작하면 이전 거리 스트림을 닫는다")
    func restartClosesPreviousStream() async {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let stream = coordinator.distances()

        coordinator.start(preview: makePreview())

        let terminal = await firstDistance(from: stream)
        #expect(terminal != nil, "앞 스트림을 덮어쓰면 그 소비자가 영원히 기다린다")
        #expect((terminal ?? nil) == nil)
    }

    @Test("종료 뒤 온 피어 소실은 아무 데도 흘리지 않는다")
    func loseAfterStopIsInert() async {
        let coordinator = PeerRangingCoordinator()
        coordinator.start(preview: makePreview())
        let stream = coordinator.distances()
        coordinator.stopAll()

        coordinator.didLosePeer("peer-1")

        // 닫힌 스트림이라 값 없이 곧바로 끝나야 한다.
        var values: [PeerDistance] = []
        for await distance in stream { values.append(distance) }
        #expect(values.isEmpty)
    }
}
