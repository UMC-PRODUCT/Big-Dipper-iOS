//
//  CardExchangeRemote.swift
//  BusinessCardData
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import Moya
import CoreNetwork

/// 아직 서버에 올리지 못한 교환 한 건.
///
/// `@Model` 레코드를 메인 액터 밖으로 내보내지 않으려고 값 타입으로 꺼낸다 —
/// 네트워크 왕복은 메인 액터 밖에서 돌기 때문이다.
public struct PendingCardExchange: Equatable, Sendable {

    // MARK: - Property

    public let cardMemberId: String
    /// `"QR"` · `"NEARBY"`.
    public let source: String
    /// ISO8601(UTC). **로컬에 기록된 실제 교환 시각**이다 — 서버가 도착 시각을 찍으면
    /// 오프라인 교환분과 기존 명함첩 이행분이 전부 오늘 날짜로 뭉친다.
    public let exchangedAt: String

    // MARK: - Init

    public init(cardMemberId: String, source: String, exchangedAt: String) {
        self.cardMemberId = cardMemberId
        self.source = source
        self.exchangedAt = exchangedAt
    }
}

/// 명함첩 동기화의 원격 경계.
///
/// 구현체를 주입하지 않으면(`nil`) 저장소는 지금까지처럼 **로컬 전용**으로 돈다. 별도
/// 피처 플래그를 두지 않는 이유는 「켜졌는지」의 정본이 두 곳으로 갈리면 반드시
/// 어긋나기 때문이다 — 의존성이 있으면 켜진 것이다.
public protocol ReceivedCardRemoteSyncing: Sendable {

    /// 커서 한 페이지. 커서 키는 불변 `id` 라 스캔 도중 재교환 upsert 가 일어나도
    /// 항목이 앞으로 점프하지 않는다.
    func fetchExchanges(cursor: String?, size: Int) async throws -> CardExchangePageDTO

    /// 교환 성립 upsert. 서버가 `UNIQUE(owner, cardMember)` 로 받으므로 멱등이다.
    func createExchange(_ exchange: PendingCardExchange) async throws

    /// 내 쪽 행만 지운다. 상대 명함첩은 건드리지 않는다.
    func deleteExchange(cardMemberId: String) async throws
}

/// Moya 구현. 서버에 명함 API 가 배포되면 DI 한 줄로 켠다.
public final class CardExchangeRemote: ReceivedCardRemoteSyncing, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any BusinessCardNetworkRequesting
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// 운영 이니셜라이저.
    public convenience init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 테스트 seam 주입용 (baseURL fatalError 회피 — `ActivityStatRepository` 선례).
    init(networkRequesting: any BusinessCardNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    public func fetchExchanges(cursor: String?, size: Int) async throws -> CardExchangePageDTO {
        let response = try await networkRequesting.request(
            BusinessCardRouter.getCardExchanges(
                query: CardExchangePageQueryDTO(cursor: cursor, size: size)
            )
        )
        return try decoder.decodeAbsorbingWrapper(CardExchangePageDTO.self, from: response.data)
    }

    public func createExchange(_ exchange: PendingCardExchange) async throws {
        let response = try await networkRequesting.request(
            BusinessCardRouter.createCardExchange(
                body: CreateCardExchangeRequestDTO(
                    cardMemberId: exchange.cardMemberId,
                    source: exchange.source,
                    exchangedAt: exchange.exchangedAt
                )
            )
        )
        try validateEnvelope(response.data)
    }

    public func deleteExchange(cardMemberId: String) async throws {
        let response = try await networkRequesting.request(
            BusinessCardRouter.deleteCardExchange(cardMemberId: cardMemberId)
        )
        try validateEnvelope(response.data)
    }

    // MARK: - Private Function

    /// 2xx 인데 `success: false` 인 응답을 성공으로 읽지 않는다.
    ///
    /// 본문이 공통 봉투가 아니면(204 등) 검사할 것이 없다 — HTTP 상태는 `NetworkClient`
    /// 가 이미 걸렀으므로 여기까지 온 것은 2xx 다.
    private func validateEnvelope(_ data: Data) throws {
        guard let envelope = try? decoder.decode(APIResponse<EmptyResult>.self, from: data) else {
            return
        }
        try envelope.validateSuccess()
    }
}
