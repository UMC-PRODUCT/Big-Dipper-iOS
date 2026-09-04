//
//  CreateCardExchangeRequestDTO.swift
//  BusinessCardData
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation

/// 교환 성립 요청 (`POST /api/v1/cards/exchanges`).
///
/// `cardMemberId` 와 `slug` 중 **정확히 하나**를 채운다. 근거리 교환 페이로드는 slug를
/// 나르지 않고, 상대가 slug 미발급 상태일 수도 있어서 memberId 경로가 반드시 필요하다.
///
/// `exchangedAt` 을 싣는 이유: 근거리 교환은 인터넷 없이 성립하므로 서버 도달이 며칠 뒤일
/// 수 있다. 서버가 도착 시각을 찍으면 「OT에서 만난 사람」이 사흘 뒤로 기록되고, 기존
/// 로컬 명함첩 이행분은 전부 이행 당일로 뭉친다.
///
/// - Note: Request(Encodable)라 custom Codable 대상이 아니다 (핵심 규칙 #3 예외).
///   합성 인코딩은 옵셔널을 `encodeIfPresent` 로 처리하므로 `nil` 필드는 키가 생략된다.
public struct CreateCardExchangeRequestDTO: Encodable, Equatable, Sendable {

    // MARK: - Property

    public let cardMemberId: String?
    public let slug: String?
    /// `"QR"` · `"NEARBY"` · `"BULK"`. 앱이 실제로 쓰는 값은 이 셋뿐이다.
    public let source: String
    /// ISO8601(UTC). 생략하면 서버가 수신 시각을 찍는다.
    public let exchangedAt: String?

    // MARK: - Init

    public init(
        cardMemberId: String? = nil,
        slug: String? = nil,
        source: String,
        exchangedAt: String? = nil
    ) {
        self.cardMemberId = cardMemberId
        self.slug = slug
        self.source = source
        self.exchangedAt = exchangedAt
    }
}
