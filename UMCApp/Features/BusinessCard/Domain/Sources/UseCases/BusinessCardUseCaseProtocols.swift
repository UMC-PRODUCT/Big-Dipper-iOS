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
///
/// `ownerMemberId` 를 두 경로 모두에서 **필수**로 받는다. 옵셔널로 두면 호출부가 조용히
/// 빼먹고, 그러면 자기 명함이 명함첩에 섞인다 — 같은 계정 두 대로 교환하거나 자기 QR 을
/// 찍었을 때 실제로 그랬다.
public protocol SaveReceivedCardUseCaseProtocol: Sendable {

    /// - Returns: 저장한 명함. 상대가 **나 자신**이면 저장하지 않고 `nil`.
    func execute(
        payload: ExchangePayload,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard?

    /// 이미 복원된 명함을 저장한다 (QR 딥링크 경로).
    ///
    /// 딥링크는 서버 조회로 ``MyCard``를 바로 얻으므로 ``ExchangePayload``를 거칠 이유가 없다.
    /// 페이로드는 근거리 전송(``CoreNearbyExchange``)의 스키마인데, 전송이 개입하지 않는
    /// 경로까지 그 타입을 끌어들이면 경계가 흐려진다.
    ///
    /// - Parameter cardID: 명함첩 중복 판정에 쓰는 키. 같은 상대를 다시 스캔했을 때 한 장으로
    ///   합쳐지도록 **memberId에서 결정적으로** 만들어야 한다.
    /// - Returns: 저장한 명함. 상대가 **나 자신**이면 저장하지 않고 `nil`.
    func execute(
        card: MyCard,
        cardID: String,
        ownerMemberId: String,
        exchangeContext: String?,
        exchangeMethod: ExchangeMethod
    ) async throws -> ReceivedCard?
}

/// 명함첩 항목의 교환 맥락 메모 갱신 (#1227).
///
/// 방식(``ExchangeMethod``)은 앱이 자동으로 채우지만 「어디서·무슨 자리에서」는 알 방법이
/// 없다. 교환 직후에 물으면 대화를 끊으므로, 나중에 상세 화면에서 적게 한다.
public protocol UpdateExchangeContextUseCaseProtocol: Sendable {
    /// - Returns: 메모가 반영된 명함.
    func execute(card: ReceivedCard, context: String?) async throws -> ReceivedCard
}

/// 명함첩 항목 삭제.
public protocol DeleteReceivedCardUseCaseProtocol: Sendable {
    func execute(id: String) async throws

    /// 현재 계정의 명함첩을 통째로 비운다 — **회원 탈퇴 전용**.
    ///
    /// 로그아웃에는 쓰지 않는다. 명함첩은 서버 사본이 없어서 잠깐 로그아웃했다 돌아온
    /// 사용자의 명함까지 날아간다. 계정 간 격리는 저장소의 소유자 스코프가 이미 해낸다.
    func executeAll() async throws
}

/// 명함첩을 서버 집합으로 재조정한다.
///
/// ``FetchReceivedCardsUseCaseProtocol`` 과 나누는 이유는 실패의 처리가 다르기 때문이다 —
/// 동기화가 실패해도 캐시로 목록은 떠야 한다. 실패를 여기서 삼키지 않고 그대로 던지는
/// 것은 호출부(명함첩 화면·검증 하네스)가 각자 다르게 다루기 때문이다.
public protocol SyncReceivedCardsUseCaseProtocol: Sendable {
    func execute() async throws
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
