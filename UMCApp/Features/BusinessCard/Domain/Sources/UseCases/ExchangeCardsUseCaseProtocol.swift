//
//  ExchangeCardsUseCaseProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNearbyExchange

/// 교환 세션 진행 상태 이벤트 (wifiwnd 화면이 그대로 구독).
public enum ExchangeEvent: Sendable, Equatable {
    case advertising                    // 광고 시작됨
    case scanning                       // 스캔 시작됨
    case peerFound(DiscoveredPeer)      // 주변 명함 발견 (wifiwnd 리스트 행)
    case sent(DiscoveredPeer)           // 선택한 피어에게 내 명함 전송됨
    case received(ReceivedCard)         // 상대 명함 수신·저장됨 (교환 완료 화면 데이터)
    /// UWB 실측 거리 갱신 (wifiwnd 행 우측 「2.1m」).
    ///
    /// **명함 전송과 무관한 이벤트다.** 거리는 NearbyInteraction 이 재고, 교환 전에도
    /// 계속 흐른다. UWB 미탑재 기기이거나 범위를 벗어나면 `meters` 가 `nil` 이다.
    case distanceUpdated(peerID: String, meters: Double?)
    case failed(NearbyError)            // 시작 실패·세션 만료

    /// `NearbyError`는 Equatable이 아니라 failed는 케이스 일치로 갈음한다.
    public static func == (lhs: ExchangeEvent, rhs: ExchangeEvent) -> Bool {
        switch (lhs, rhs) {
        case (.advertising, .advertising), (.scanning, .scanning):
            return true
        case (.peerFound(let lhsPeer), .peerFound(let rhsPeer)):
            return lhsPeer == rhsPeer
        case (.sent(let lhsPeer), .sent(let rhsPeer)):
            return lhsPeer == rhsPeer
        case (.received(let lhsCard), .received(let rhsCard)):
            return lhsCard == rhsCard
        case (.distanceUpdated(let lhsID, let lhsMeters),
              .distanceUpdated(let rhsID, let rhsMeters)):
            return lhsID == rhsID && lhsMeters == rhsMeters
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

public protocol ExchangeCardsUseCaseProtocol: Sendable {
    /// 광고+스캔을 한 세션으로 시작한다. 스트림 종료 = 세션 종료.
    func start(myCard: MyCard) -> AsyncStream<ExchangeEvent>
    /// 발견된 피어에게 내 명함을 전송한다 (wifiwnd 행 선택).
    func send(myCard: MyCard, to peer: DiscoveredPeer) async throws
    /// 세션 중단 (화면 이탈·취소). 광고 중지 + 스트림 finish.
    func stop() async
}
