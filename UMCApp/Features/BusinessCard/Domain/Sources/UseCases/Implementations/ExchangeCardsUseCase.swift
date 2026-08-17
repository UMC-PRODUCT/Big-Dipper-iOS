//
//  ExchangeCardsUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNearbyExchange

/// 근거리 명함 교환 세션 오케스트레이션 (wifiwnd 화면의 기능부).
///
/// 광고(내 명함 노출)와 스캔(주변 명함 발견)을 한 세션으로 묶고, 수신한 페이로드를
/// 명함첩에 저장한 뒤 이벤트로 흘린다. 타임아웃(기본 5분)·취소는 여기(UseCase 정책)이고
/// transport는 start/stop만 안다 (PRD Q4).
///
/// 스파이크 반영: 상대 페이로드가 연결 수립 이벤트보다 먼저 도착할 수 있으므로
/// 수신 스트림은 `start` 진입 시점에 동기 구독을 확정한다.
public final class ExchangeCardsUseCase: ExchangeCardsUseCaseProtocol, @unchecked Sendable {

    // MARK: - Property

    private let transport: NearbyTransportProtocol
    private let saveReceivedCard: SaveReceivedCardUseCaseProtocol
    private let sessionTimeout: Duration
    /// UWB 거리 측정. 없으면 거리 없이 발견·교환만 동작한다 (구형 기기·시뮬레이터).
    private let ranging: PeerRangingCoordinator?

    private let stateQueue = DispatchQueue(label: "dev.umc.businesscard.exchange")
    private var continuation: AsyncStream<ExchangeEvent>.Continuation?
    private var sessionTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    /// 수신 루프. 세션 종료 시 반드시 취소한다 — 비구조 Task로 두면 sessionTask 취소가
    /// 전파되지 않아 transport(→self)를 강참조한 채 영원히 남는다 (스파이크 ④).
    private var receiveTask: Task<Void, Never>?
    /// 거리 갱신 루프. 수신 루프와 같은 이유로 세션 종료 시 취소한다.
    private var rangingTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        transport: NearbyTransportProtocol,
        saveReceivedCard: SaveReceivedCardUseCaseProtocol,
        sessionTimeout: Duration = .seconds(5 * 60),
        ranging: PeerRangingCoordinator? = nil
    ) {
        self.transport = transport
        self.saveReceivedCard = saveReceivedCard
        self.sessionTimeout = sessionTimeout
        self.ranging = ranging

        // transport 가 연결마다 핸드셰이크를 물어보게 한다. 토큰은 피어마다 달라야 해서
        // 전역으로 미리 만들어 둘 수 없다 (PeerRangingCoordinator 주석 참고).
        if let ranging, let mpc = transport as? MPCTransport {
            mpc.setHandshakeProvider(ranging)
        }
    }

    // MARK: - Function

    public func start(myCard: MyCard) -> AsyncStream<ExchangeEvent> {
        // 재시작 시 이전 세션을 먼저 정리한다 — 덮어쓰면 앞 스트림 소비자가 영구 대기.
        finish()

        // 수신 구독은 여기서 동기 호출한다. AsyncStream의 build 클로저는 생성 시점에
        // 동기 실행되므로 이 시점에 transport의 continuation 등록이 확정된다.
        // Task 안에서 호출하면 스케줄링에 따라 광고가 먼저 시작돼 선착 페이로드를
        // 놓칠 수 있다 (스파이크 ③은 순서가 아니라 구조로 보장해야 한다).
        let receiveStream = transport.receive()

        // 거리 스트림도 같은 이유로 여기서 동기 구독한다 — 연결 직후 핸드셰이크가 오가면
        // 곧바로 갱신이 흐르기 시작하므로, Task 안에서 열면 초기 값을 놓친다.
        ranging?.start(preview: myCard.toPeerPreview())
        let distanceStream = ranging?.distances()

        return AsyncStream { continuation in
            stateQueue.sync { self.continuation = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.tearDown()
            }

            let receiveWork = Task { [weak self] in
                for await payload in receiveStream {
                    guard let self, !Task.isCancelled else { return }
                    await self.handleReceived(payload, ownerMemberId: myCard.memberId)
                }
            }
            stateQueue.sync { self.receiveTask = receiveWork }

            if let distanceStream {
                let rangingWork = Task { [weak self] in
                    for await distance in distanceStream {
                        guard let self, !Task.isCancelled else { return }
                        self.yield(
                            .distanceUpdated(peerID: distance.peerID, meters: distance.meters)
                        )
                    }
                }
                stateQueue.sync { self.rangingTask = rangingWork }
            }

            let sessionWork = Task { [weak self] in
                guard let self else { return }

                do {
                    let payload = try myCard.toExchangePayload()
                    try await self.transport.startAdvertising(card: payload)
                    self.yield(.advertising)
                } catch let error as NearbyError {
                    self.yield(.failed(error))
                    self.finish()
                    return
                } catch {
                    self.yield(.failed(.transportFailure(underlying: error)))
                    self.finish()
                    return
                }

                self.yield(.scanning)
                for await peer in self.transport.startScanning() {
                    self.yield(.peerFound(peer))
                }
                // 스캔 스트림이 끝나도 세션은 타임아웃/stop까지 유지된다.
                // receiveTask를 여기서 await하지 않는다 — 대기하면 취소가 닿지 않아
                // 세션마다 태스크가 누적 누수된다(DIContainer는 인스턴스를 캐싱).
            }
            stateQueue.sync { self.sessionTask = sessionWork }

            let timeoutWork = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.sessionTimeout)
                guard !Task.isCancelled else { return }
                self.yield(.failed(.sessionExpired))
                await self.transport.stopAdvertising()
                self.finish()
            }
            stateQueue.sync { self.timeoutTask = timeoutWork }
        }
    }

    public func send(myCard: MyCard, to peer: DiscoveredPeer) async throws {
        let payload = try myCard.toExchangePayload()
        try await transport.send(payload: payload, to: peer)
        yield(.sent(peer))
    }

    public func stop() async {
        await transport.stopAdvertising()
        finish()
    }

    // MARK: - Private Function

    /// 내 명함이 돌아오면(같은 계정 두 대) 저장도 이벤트도 없다 — 교환 완료 화면이
    /// 자기 명함을 「받았다」고 띄우는 것보다 아무 일도 없는 게 맞다.
    private func handleReceived(_ payload: ExchangePayload, ownerMemberId: String) async {
        do {
            let card = try await saveReceivedCard.execute(
                payload: payload,
                ownerMemberId: ownerMemberId,
                exchangeContext: nil
            )
            guard let card else { return }
            yield(.received(card))
        } catch {
            yield(.failed(.transportFailure(underlying: error)))
        }
    }

    private func yield(_ event: ExchangeEvent) {
        stateQueue.sync { _ = continuation?.yield(event) }
    }

    /// 스트림을 닫는다. 어떤 경로로 끝나든 continuation leak을 남기지 않는다 (스파이크 ④).
    ///
    /// `finish()`는 **락 밖에서** 호출한다 — `onTermination` 핸들러가 finish를 호출한
    /// 그 스레드에서 동기 실행되므로, 락 안에서 부르면 같은 직렬 큐에 재진입해 데드락난다.
    private func finish() {
        let pending = stateQueue.sync { () -> AsyncStream<ExchangeEvent>.Continuation? in
            let current = continuation
            continuation = nil
            return current
        }
        pending?.finish()
        tearDown()
    }

    private func tearDown() {
        stateQueue.sync {
            sessionTask?.cancel()
            sessionTask = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            receiveTask?.cancel()   // 비구조 Task라 sessionTask 취소로는 안 닿는다
            receiveTask = nil
            rangingTask?.cancel()
            rangingTask = nil
        }
        // NI 세션은 락 밖에서 정리한다 — invalidate 가 델리게이트를 동기 호출할 수 있다.
        ranging?.stopAll()
    }
}
