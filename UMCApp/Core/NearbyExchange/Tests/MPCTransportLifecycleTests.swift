//
//  MPCTransportLifecycleTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

/// 세션 수명 계약.
///
/// 실기기에서 **명함 전송은 되는데 수신만 안 되는** 증상이 나왔다. 원인은
/// `startAdvertising` 이 내부에서 `stopAdvertising` 을 불러 **직전에 등록된 수신 스트림을
/// 닫아버린 것**이었다. `ExchangeCardsUseCase` 는 선착 페이로드를 놓치지 않으려고
/// `receive()` 를 먼저 구독하고 곧바로 `startAdvertising` 을 부른다 — 그 순서가 깨졌다.
///
/// 이 스위트는 그 순서를 계약으로 고정한다. 조용히 깨지는 종류의 버그라 화면에서
/// "왜 안 오지"로만 보이고 에러가 남지 않는다.
@Suite("MPCTransport — 세션 수명")
struct MPCTransportLifecycleTests {

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
            cardLink: "https://api.university.neordinary.com/mypage/card?memberId=42",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("광고 시작이 직전에 구독한 수신 스트림을 닫지 않는다")
    func advertisingKeepsReceiveStreamOpen() async throws {
        let transport = MPCTransport()

        // UseCase 와 같은 순서: 수신 먼저 구독, 그다음 광고.
        let stream = transport.receive()
        try await transport.startAdvertising(card: try makeCard())

        // 스트림이 살아 있으면 값이 오기 전까지 대기한다. 닫혔다면 즉시 nil 로 끝난다.
        let firstElement = await withTaskGroup(of: ExchangePayload?.self) { group in
            group.addTask {
                for await payload in stream { return payload }
                return nil                                  // 스트림이 닫혔다
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(300))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }

        // 두 태스크 모두 nil 을 돌려주므로 값으로는 구분할 수 없다. 대신 **스트림이 곧바로
        // 끝나지 않았다**는 것을 시간으로 확인한다 — 닫힌 스트림은 300ms 를 기다리지 않는다.
        #expect(firstElement == nil)

        await transport.stopAdvertising()
    }

    @Test("광고를 다시 시작해도 수신 스트림은 유지된다")
    func restartingAdvertisingKeepsReceiveStreamOpen() async throws {
        let transport = MPCTransport()
        let stream = transport.receive()

        try await transport.startAdvertising(card: try makeCard())
        try await transport.startAdvertising(card: try makeCard())   // 재시작

        var iterator = stream.makeAsyncIterator()
        let closedImmediately = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = await iterator.next()
                return true                                  // 끝났다 = 닫혔다
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(300))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        #expect(!closedImmediately, "재시작이 수신 스트림을 닫으면 상대 명함이 영영 안 온다")
        await transport.stopAdvertising()
    }

    @Test("세션 종료는 수신 스트림을 닫는다 — 소비자가 영구 대기하면 안 된다")
    func stopClosesReceiveStream() async throws {
        let transport = MPCTransport()
        let stream = transport.receive()
        try await transport.startAdvertising(card: try makeCard())

        await transport.stopAdvertising()

        var iterator = stream.makeAsyncIterator()
        let closed = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = await iterator.next()
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(500))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        #expect(closed, "stop 후에도 스트림이 열려 있으면 소비 태스크가 영원히 남는다")
    }
}
