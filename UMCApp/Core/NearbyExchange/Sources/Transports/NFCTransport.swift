//
//  NFCTransport.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation
import CoreNFC

// MARK: - NFCTransport

/// Phase 1 NFC 전송 구현체.
///
/// NFCNDEFReaderSession 기반 탭-to-exchange (1:1 즉석 교환, iOS 대상).
/// NFC는 1:1 단발성 교환 전용이므로 `startScanning`/`startAdvertising` 개념이 다르다.
/// 이 구현은 `startAdvertising`을 "NFC 쓰기 세션 준비"로,
/// `startScanning`을 "NFC 읽기 세션 시작"으로 매핑한다.
///
/// 실제 데이터 R/W 완결 로직은 후속 이슈에서 구현 예정.
public final class NFCTransport: NSObject, NearbyTransportProtocol {

    // MARK: - Property

    private var readerSession: NFCNDEFReaderSession?
    private var peerContinuation: AsyncStream<DiscoveredPeer>.Continuation?
    private var receiveContinuation: AsyncStream<ExchangePayload>.Continuation?

    // NFC MIME 타입 (PRD v3 확정)
    private let nfcMIMEType = "application/vnd.umc.businesscard+json"

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - NearbyTransportProtocol

    /// NFC는 광고 개념 없이 탭 시 즉시 교환. 이 메서드는 no-op.
    public func startAdvertising(payload: BLEAdvertisementPayload) async throws {
        // NFC 방식에서는 광고가 아닌 탭 이벤트가 교환 트리거이므로 별도 처리 불필요.
    }

    public func stopAdvertising() async {}

    /// NFC 탭 감지를 위한 읽기 세션 시작.
    /// 탭 발생 → `DiscoveredPeer`를 stream에 yield → `send`로 즉시 응답하는 흐름.
    public func startScanning() -> AsyncStream<DiscoveredPeer> {
        AsyncStream { continuation in
            self.peerContinuation = continuation

            guard NFCNDEFReaderSession.readingAvailable else {
                continuation.finish()
                return
            }

            let session = NFCNDEFReaderSession(
                delegate: self,
                queue: .main,
                invalidateAfterFirstRead: false
            )
            session.alertMessage = "명함을 교환할 기기에 가까이 대세요."
            self.readerSession = session
            // TODO: session.begin() — 실제 운용 시 활성화.
            // 현재 시뮬레이터 지원 불가로 주석 처리. 후속 이슈에서 활성화.

            continuation.onTermination = { [weak self] _ in
                self?.readerSession?.invalidate()
                self?.readerSession = nil
                self?.peerContinuation = nil
            }
        }
    }

    /// NFC 탭 후 NDEF 레코드로 ExchangePayload JSON을 전송.
    /// 실제 데이터 쓰기는 후속 이슈에서 구현 예정.
    public func send(payload: ExchangePayload, to peer: DiscoveredPeer) async throws {
        // TODO: NFCNDEFTag에 MIME 타입 레코드 작성.
        //        레코드: NFCNDEFPayload(format: .media,
        //                              type: nfcMIMEType.data(using: .utf8)!,
        //                              identifier: Data(),
        //                              payload: payload.jsonData())
        throw NearbyError.notImplemented
    }

    public func receive() -> AsyncStream<ExchangePayload> {
        AsyncStream { continuation in
            self.receiveContinuation = continuation
            // TODO: NFC NDEF 읽기 성공 시 ExchangePayload.decode(from:) 거쳐 yield.
            continuation.onTermination = { [weak self] _ in
                self?.receiveContinuation = nil
            }
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCTransport: NFCNDEFReaderSessionDelegate {
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // NFCReaderError.readerSessionInvalidationErrorUserCanceled는 정상 종료
        peerContinuation?.finish()
        readerSession = nil
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // TODO: messages에서 nfcMIMEType 레코드 추출 →
        //        ExchangePayload.decode(from:) → receiveContinuation.yield.
        //        동시에 임시 DiscoveredPeer를 생성해 peerContinuation.yield 호출.
    }
}
