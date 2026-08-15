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

/// 명함첩 목록·검색 (MP-F05).
public protocol FetchReceivedCardsUseCaseProtocol: Sendable {
    /// query가 nil·공백이면 전체 목록.
    func execute(query: String?) async throws -> [ReceivedCard]
}

/// 수신 페이로드를 명함첩에 저장 (교환·QR 스캔 공용 진입점).
public protocol SaveReceivedCardUseCaseProtocol: Sendable {
    func execute(payload: ExchangePayload, exchangeContext: String?) async throws -> ReceivedCard
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
