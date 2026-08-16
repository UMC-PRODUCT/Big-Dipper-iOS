//
//  NearbyMessageTests.swift
//  CoreNearbyExchangeTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import CoreNearbyExchange

/// 연결 위로 오가는 봉투의 계약.
///
/// 두 케이스가 **같은 채널**에 섞여 흐르므로, 디코딩이 종류를 정확히 갈라내지 못하면
/// 미리보기가 명함으로 오인되거나 그 반대가 된다. 왕복을 고정한다.
@Suite("NearbyMessage — 봉투 왕복")
struct NearbyMessageTests {

    /// `timestamp`를 정수 초로 고정한다.
    ///
    /// 전송 포맷이 ISO8601이라 소수점 이하 초가 인코딩에서 잘린다. `Date()` 기본값을 쓰면
    /// 왕복 후 마이크로초가 어긋나 동등 비교가 실패한다 — 봉투의 결함이 아니라 날짜 표현의
    /// 성질이므로, 그 성질을 피해서 봉투만 검증한다.
    private func makePayload() throws -> ExchangePayload {
        try ExchangePayload(
            cardID: "CARD-1",
            name: "정의찬",
            nickname: "제옹",
            part: "IOS",
            generation: "12",
            university: "한양대학교",
            email: nil,
            github: "github.com/one",
            linkedIn: nil,
            blog: nil,
            avatarURL: nil,
            cardLink: "https://api.university.neordinary.com/mypage/card?memberId=42",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makePreview() -> PeerPreview {
        PeerPreview(
            name: "정의찬",
            nickname: "제옹",
            part: "IOS",
            generation: "12",
            avatarURL: "https://cdn.umc.it.kr/a.png"
        )
    }

    @Test("handshake 왕복 — 미리보기와 NI 토큰이 보존된다")
    func handshakeRoundtrip() throws {
        let token = Data(repeating: 0xAB, count: 343)
        let message = NearbyMessage.handshake(
            NearbyHandshake(preview: makePreview(), niToken: token)
        )

        let decoded = try JSONDecoder().decode(
            NearbyMessage.self, from: try JSONEncoder().encode(message)
        )

        guard case .handshake(let handshake) = decoded else {
            Issue.record("handshake로 디코딩되지 않음"); return
        }
        #expect(handshake.preview == makePreview())
        #expect(handshake.niToken == token)
    }

    @Test("UWB 미탑재 기기의 handshake — 토큰이 nil이어도 미리보기는 온다")
    func handshakeWithoutToken() throws {
        let message = NearbyMessage.handshake(
            NearbyHandshake(preview: makePreview(), niToken: nil)
        )

        let decoded = try JSONDecoder().decode(
            NearbyMessage.self, from: try JSONEncoder().encode(message)
        )

        guard case .handshake(let handshake) = decoded else {
            Issue.record("handshake로 디코딩되지 않음"); return
        }
        #expect(handshake.niToken == nil)
        #expect(handshake.preview.name == "정의찬")
    }

    @Test("card 왕복 — 명함 페이로드가 그대로 보존된다")
    func cardRoundtrip() throws {
        let payload = try makePayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            NearbyMessage.self, from: try encoder.encode(NearbyMessage.card(payload))
        )

        guard case .card(let restored) = decoded else {
            Issue.record("card로 디코딩되지 않음"); return
        }
        #expect(restored == payload)
    }

    @Test("두 종류가 섞여도 서로 오인되지 않는다")
    func kindsAreDistinguished() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let handshakeData = try encoder.encode(
            NearbyMessage.handshake(NearbyHandshake(preview: makePreview(), niToken: nil))
        )
        let cardData = try encoder.encode(NearbyMessage.card(try makePayload()))

        if case .card = try decoder.decode(NearbyMessage.self, from: handshakeData) {
            Issue.record("handshake가 card로 오인됨")
        }
        if case .handshake = try decoder.decode(NearbyMessage.self, from: cardData) {
            Issue.record("card가 handshake로 오인됨")
        }
    }

    @Test("미리보기에는 이메일·외부 링크가 없다 — 동의 전에 흐르는 정보라 최소여야 한다")
    func previewCarriesMinimumFields() throws {
        let data = try JSONEncoder().encode(makePreview())
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("email"))
        #expect(!json.contains("github"))
        #expect(!json.contains("blog"))
        #expect(!json.contains("cardLink"))
    }
}
