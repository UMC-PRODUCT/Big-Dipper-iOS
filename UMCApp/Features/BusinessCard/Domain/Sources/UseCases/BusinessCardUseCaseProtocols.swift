//
//  BusinessCardUseCaseProtocols.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import CoreGraphics
import Foundation
import CoreNearbyExchange

/// 내 명함 조회 (MP-F01).
public protocol FetchMyCardUseCaseProtocol: Sendable {
    func execute(forceRefresh: Bool) async throws -> MyCard
}

/// 상대 명함 조회 (QR 딥링크 스캔).
///
/// 딥링크는 memberId만 싣는다 — 명함 내용은 서버에서 받아 온다.
public protocol FetchPeerCardUseCaseProtocol: Sendable {
    func execute(memberId: String) async throws -> MyCard
}

/// 명함첩 목록·검색 (MP-F05).
public protocol FetchReceivedCardsUseCaseProtocol: Sendable {
    /// query가 nil·공백이면 전체 목록.
    func execute(query: String?) async throws -> [ReceivedCard]
}

/// 수신 페이로드를 명함첩에 저장 (교환·QR 스캔 공용 진입점).
public protocol SaveReceivedCardUseCaseProtocol: Sendable {
    func execute(payload: ExchangePayload, exchangeContext: String?) async throws -> ReceivedCard

    /// 이미 복원된 명함을 저장한다 (QR 딥링크 경로).
    ///
    /// 딥링크는 서버 조회로 ``MyCard``를 바로 얻으므로 ``ExchangePayload``를 거칠 이유가 없다.
    /// 페이로드는 근거리 전송(``CoreNearbyExchange``)의 스키마인데, 전송이 개입하지 않는
    /// 경로까지 그 타입을 끌어들이면 경계가 흐려진다.
    ///
    /// - Parameter cardID: 명함첩 중복 판정에 쓰는 키. 같은 상대를 다시 스캔했을 때 한 장으로
    ///   합쳐지도록 **memberId에서 결정적으로** 만들어야 한다.
    func execute(
        card: MyCard,
        cardID: String,
        exchangeContext: String?
    ) async throws -> ReceivedCard
}

/// 명함첩 항목 삭제.
public protocol DeleteReceivedCardUseCaseProtocol: Sendable {
    func execute(id: String) async throws
}

/// 마이페이지 행 우측 숫자 일괄 공급 (MP-F07~F09).
public protocol FetchActivityStatUseCaseProtocol: Sendable {
    /// 던지지 않는다 — 소스별 실패는 "0" 폴백 (MP-F07).
    func execute() async -> ActivityStat
}

/// 명함 QR 생성 (MP-F02 뒷면·MP-F04).
public protocol GenerateCardQRUseCaseProtocol: Sendable {
    func execute(for card: MyCard) throws -> CGImage
}
