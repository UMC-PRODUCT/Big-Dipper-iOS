//
//  ExchangeCardsUseCase.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNearbyExchange

// MARK: - Constants

private enum Constants {
    /// 전송 시도 횟수(최초 1회 + 재시도 2회).
    static let sendAttempts = 3
    /// 재시도 사이 간격. 순간적인 연결 흔들림이 가라앉을 만큼만 짧게 둔다.
    static let sendBackoff: [Duration] = [.milliseconds(500), .milliseconds(1_500)]
}

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
    /// 마지막 활동 이후 이만큼 아무 일도 없으면 세션을 끝낸다.
    private let idleTimeout: Duration
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
        idleTimeout: Duration = .seconds(5 * 60),
        ranging: PeerRangingCoordinator? = nil
    ) {
        self.transport = transport
        self.saveReceivedCard = saveReceivedCard
        self.idleTimeout = idleTimeout
        self.ranging = ranging

        // transport 가 연결마다 핸드셰이크를 물어보게 한다. 토큰은 피어마다 달라야 해서
        // 전역으로 미리 만들어 둘 수 없다 (PeerRangingCoordinator 주석 참고).
        if let ranging {
            transport.setHandshakeProvider(ranging)
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
                    self.yield(.failed(BusinessCardError(error)))
                    self.finish()
                    return
                } catch {
                    self.yield(.failed(.exchangeFailed(reason: "\(error)")))
                    self.finish()
                    return
                }

                self.yield(.scanning)
                for await event in self.transport.startScanning() {
                    switch event {
                    case .found(let peer):
                        self.yield(.peerFound(peer))
                    case .lost(let peerID):
                        self.yield(.peerLost(peerID: peerID))
                    case .failed(let error):
                        self.yield(.failed(BusinessCardError(error)))
                    }
                }
                // 스캔 스트림이 끝나도 세션은 타임아웃/stop까지 유지된다.
                // receiveTask를 여기서 await하지 않는다 — 대기하면 취소가 닿지 않아
                // 세션마다 태스크가 누적 누수된다(DIContainer는 인스턴스를 캐싱).
            }
            stateQueue.sync { self.sessionTask = sessionWork }

            restartIdleTimer()
        }
    }

    public func send(myCard: MyCard, to peer: DiscoveredPeer) async throws {
        let payload = try myCard.toExchangePayload()
        do {
            try await sendWithRetry(payload, to: peer)
        } catch let error as NearbyError {
            throw BusinessCardError(error)
        }
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
            // 저장 실패를 전송 실패로 감싸면 화면이 「연결하지 못했어요」를 띄운다.
            // 교환 자체는 성공했고 명함첩에 넣는 데만 실패했다 — 재시도가 의미 있다.
            yield(.failed(.saveFailed(reason: "\(error)")))
        }
    }

    /// 연결이 한 번 흔들렸다고 교환 전체를 실패시키지 않는다. MPC 는 시도마다
    /// 초대·연결을 다시 태우므로 재시도가 실제로 다른 결과를 낸다.
    ///
    /// 다만 상대가 이미 사라졌으면 재시도는 손해다 — 없는 기기에게 건 초대는
    /// 연결 타임아웃(20초)을 통째로 태운 뒤에야 실패한다.
    private func sendWithRetry(_ payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        for attempt in 0..<Constants.sendAttempts {
            if attempt > 0 {
                try? await Task.sleep(for: Constants.sendBackoff[attempt - 1])
            }
            do {
                return try await transport.send(payload: payload, to: peer)
            } catch let error as NearbyError where !Self.isRetryable(error) {
                throw error
            } catch {
                guard attempt == Constants.sendAttempts - 1 else { continue }
                throw error
            }
        }
    }

    /// 다시 걸어 볼 가치가 있는 실패인지. 상대 부재·권한·페이로드 오류는 몇 번을
    /// 걸어도 같은 결과다.
    private static func isRetryable(_ error: NearbyError) -> Bool {
        switch error {
        case .peerUnavailable, .permissionDenied, .invalidPayload, .unsupported:
            return false
        case .transportFailure, .sessionExpired:
            return true
        }
    }

    /// idle 타이머를 처음부터 다시 건다.
    ///
    /// 절대 시간으로 자르면 활발히 교환하는 중에도 세션이 끊긴다. 반대로 타이머가
    /// 아예 없으면 화면을 켜 둔 채 두었을 때 광고가 무기한 돌아 배터리를 태우고
    /// 주변에 이름을 계속 노출한다.
    private func restartIdleTimer() {
        let work = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.idleTimeout)
            guard !Task.isCancelled else { return }
            self.yield(.failed(.sessionExpired))
            // 광고·탐색·세션을 모두 걷는다 — 스트림만 닫으면 transport 는 계속 돈다.
            await self.transport.stopAdvertising()
            self.finish()
        }
        let previous = stateQueue.sync { () -> Task<Void, Never>? in
            let old = timeoutTask
            timeoutTask = work
            return old
        }
        previous?.cancel()
    }

    /// 사용자가 실제로 무언가를 만난 순간만 「활동」으로 친다.
    ///
    /// 거리 갱신은 뺀다 — UWB 는 초당 여러 번 흘러서 포함하면 idle 이 영영 오지 않는다.
    private static func isActivity(_ event: ExchangeEvent) -> Bool {
        switch event {
        case .peerFound, .sent, .received:
            return true
        case .advertising, .scanning, .peerLost, .distanceUpdated, .failed:
            return false
        }
    }

    private func yield(_ event: ExchangeEvent) {
        stateQueue.sync { _ = continuation?.yield(event) }
        // 락 밖에서 건다 — 같은 직렬 큐에 재진입하면 데드락난다.
        if Self.isActivity(event) { restartIdleTimer() }
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
