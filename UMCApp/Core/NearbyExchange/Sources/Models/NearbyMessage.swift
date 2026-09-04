//
//  NearbyMessage.swift
//  CoreNearbyExchange
//
//  Created by One on 8/16/26.
//

import Foundation

// MARK: - PeerPreview

/// 발견 목록 한 줄을 그리는 데 필요한 최소 정보.
///
/// 시안(Figma 12654:32621)의 행은 아바타·이름/닉네임·파트·기수를 보여준다. 그런데 이 값들은
/// **명함을 교환하기 전에** 필요하다 — 누군지 봐야 탭할지 정하기 때문이다. MPC 는 발견 시점의
/// `discoveryInfo` 로 그중 일부를 이미 싣지만, Bonjour TXT 레코드는 크기가 빠듯하고 NI 토큰은
/// 거기 실을 수 없다. 그래서 연결 직후 핸드셰이크로 미리보기와 토큰을 함께 주고받는다.
///
/// 명함 본체(``ExchangePayload``)와 분리한 이유: 미리보기는 **동의 없이** 오간다. 사용자가
/// 행을 탭해야 비로소 명함이 건너가므로, 그 전에 흐르는 정보는 최소여야 한다.
/// 여기에 이메일·외부 링크가 없는 건 그래서다.
public struct PeerPreview: Codable, Sendable, Equatable {

    // MARK: - Property

    public let name: String
    public let nickname: String
    /// `UMCPartType.apiValue` 문자열. 서버 유래 값이라 String 유지 (핵심규칙 #2).
    public let part: String
    public let generation: String
    public let avatarURL: String?

    // MARK: - Init

    public init(
        name: String,
        nickname: String,
        part: String,
        generation: String,
        avatarURL: String?
    ) {
        self.name = name
        self.nickname = nickname
        self.part = part
        self.generation = generation
        self.avatarURL = avatarURL
    }
}

// MARK: - NearbyHandshake

/// 연결 직후 자동으로 오가는 첫 메시지.
///
/// 두 가지를 한 번에 나른다 — 목록에 그릴 ``PeerPreview`` 와 UWB 레인징을 시작할 토큰.
/// 둘 다 "연결되자마자 필요한 메타데이터"라 같은 메시지에 싣는다.
public struct NearbyHandshake: Codable, Sendable, Equatable {

    // MARK: - Property

    public let preview: PeerPreview

    /// `NIDiscoveryToken` 을 `NSKeyedArchiver` 로 직렬화한 값 (실측 343B).
    ///
    /// **NearbyInteraction 은 이 토큰을 스스로 나르지 못한다.** 거리·방향만 주는 API 라,
    /// 세션을 시작하려면 다른 채널로 토큰을 먼저 주고받아야 한다 — 그 채널이 MPC 다.
    ///
    /// UWB 미탑재 기기(아이패드·구형 아이폰)는 `nil`. 그 경우 목록에 거리 없이 행만 그린다.
    public let niToken: Data?

    // MARK: - Init

    public init(preview: PeerPreview, niToken: Data?) {
        self.preview = preview
        self.niToken = niToken
    }
}

// MARK: - NearbyMessage

/// MPC 세션 위로 오가는 메시지 봉투.
///
/// 전에는 ``ExchangePayload`` 만 오갔다. 그래서 미리보기도 NI 토큰도 실을 자리가 없었고,
/// 상대가 누군지 보려면 명함을 먼저 받아야 하는 순서 역전이 있었다.
///
/// 두 케이스의 **동의 수준이 다르다**:
/// - ``handshake`` — 연결되면 자동으로 오간다. 목록을 그리는 최소 정보뿐이다.
/// - ``card`` — 사용자가 행을 **탭해야** 건너간다. 명함 전체다.
public enum NearbyMessage: Codable, Sendable, Equatable {

    case handshake(NearbyHandshake)
    case card(ExchangePayload)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case kind
        case handshake
        case card
    }

    private enum Kind: String, Codable {
        case handshake
        case card
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .handshake:
            self = .handshake(try container.decode(NearbyHandshake.self, forKey: .handshake))
        case .card:
            self = .card(try container.decode(ExchangePayload.self, forKey: .card))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .handshake(let handshake):
            try container.encode(Kind.handshake, forKey: .kind)
            try container.encode(handshake, forKey: .handshake)
        case .card(let payload):
            try container.encode(Kind.card, forKey: .kind)
            try container.encode(payload, forKey: .card)
        }
    }
}
