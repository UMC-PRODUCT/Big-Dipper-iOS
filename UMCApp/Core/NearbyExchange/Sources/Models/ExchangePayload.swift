//
//  ExchangePayload.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

// iOS 주도 크로스 플랫폼 교환 스키마 v2 (2026-08-15 실기기 스파이크 검증).
// Android 측 구현은 아직 없다(레포 전수 확인) — 본 스키마를 정본으로 공유한다.
// v1(ownerName·usdzURL 필수) 페이로드의 "수신"은 하위호환으로 지원한다.
public struct ExchangePayload: Codable, Sendable, Equatable {

    // MARK: - Property

    public let cardID: String
    /// 실명. v1 수신 시 `ownerName` 값이 여기로 매핑된다.
    public let name: String
    public let nickname: String
    /// `UMCPartType.apiValue` 문자열 (예: "IOS"). 서버 유래 값이라 String 유지 (절대규칙 #2).
    public let part: String
    public let generation: String
    public let university: String
    public let email: String?
    public let github: String?
    /// v2 도중 추가 — `decodeIfPresent`라 이 필드가 없는 기존 v2 페이로드도 그대로 읽힌다.
    public let linkedIn: String?
    public let blog: String?
    public let avatarURL: String?
    /// 프로필 딥링크. 정본은 질의형 `umc://card?memberId={memberId}` 다 — 굽는 형식은
    /// `CardLink` 하나가 소유하므로 이 값도 거기서 만든다. 경로형 `umc://card/{memberId}`
    /// 는 이미 구워진 QR 때문에 **읽기만** 남겨 둔 폐기 대상 호환 케이스다.
    /// **memberId의 유일한 운반 수단** — 수신 측은 이 값을 파싱해 정체성을 복원한다.
    public let cardLink: String
    /// 3D 명함 에셋 URL. **의도적으로 비워 두는 슬롯이다 — 지우지 말 것.**
    ///
    /// 설계서 §6 결정: 3D 명함은 온디바이스 합성이라 수신 측이 같은 번들 템플릿으로
    /// 다시 합성한다. 그래서 페이로드에 에셋 URL 을 실을 이유가 없다. v1 이 필수로 들고
    /// 있던 필드라 수신 호환을 위해 남으며, v2 에서 옵셔널로 완화됐다.
    public let usdzURL: URL?
    public let timestamp: Date
    /// 스키마 버전. 프로토콜 메타라 Int (서버 무관 — 절대규칙 #2 대상 아님).
    public let version: Int

    public static let currentVersion = 2

    // MARK: - Init

    /// usdzURL이 있으면 HTTPS만 허용 (v1 규칙 유지).
    public init(
        cardID: String,
        name: String,
        nickname: String,
        part: String,
        generation: String,
        university: String,
        email: String?,
        github: String?,
        linkedIn: String?,
        blog: String?,
        avatarURL: String?,
        cardLink: String,
        usdzURL: URL? = nil,
        timestamp: Date = Date(),
        version: Int = ExchangePayload.currentVersion
    ) throws {
        if let usdzURL, usdzURL.scheme?.lowercased() != "https" {
            throw NearbyError.invalidPayload("usdzURL must use HTTPS scheme")
        }
        self.cardID = cardID
        self.name = name
        self.nickname = nickname
        self.part = part
        self.generation = generation
        self.university = university
        self.email = email
        self.github = github
        self.linkedIn = linkedIn
        self.blog = blog
        self.avatarURL = avatarURL
        self.cardLink = cardLink
        self.usdzURL = usdzURL
        self.timestamp = timestamp
        self.version = version
    }

    // MARK: - Codable (v1 하위호환)

    private enum CodingKeys: String, CodingKey {
        case cardID, name, nickname, part, generation, university
        case email, github, linkedIn, blog, avatarURL, cardLink
        case usdzURL, timestamp, version
        case ownerName // v1 전용
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        // 상한이 없으면 미래의 v3 를 v2 로 읽고 **틀린 값을 조용히 받아들인다.** 모르는
        // 버전은 읽을 수 없다고 말하는 편이 낫다 — 상대가 새 필드에 의미를 넣었을 때
        // 여기서 걸리지 않으면 어디서도 걸리지 않는다.
        guard (1...Self.currentVersion).contains(decodedVersion) else {
            throw NearbyError.invalidPayload(
                "지원하지 않는 페이로드 버전 \(decodedVersion) (지원 1...\(Self.currentVersion))"
            )
        }
        version = decodedVersion
        cardID = try container.decode(String.self, forKey: .cardID)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        usdzURL = try container.decodeIfPresent(URL.self, forKey: .usdzURL)

        if decodedVersion >= 2 {
            name = try container.decode(String.self, forKey: .name)
            nickname = try container.decode(String.self, forKey: .nickname)
            part = try container.decode(String.self, forKey: .part)
            generation = try container.decode(String.self, forKey: .generation)
            university = try container.decode(String.self, forKey: .university)
            email = try container.decodeIfPresent(String.self, forKey: .email)
            github = try container.decodeIfPresent(String.self, forKey: .github)
            linkedIn = try container.decodeIfPresent(String.self, forKey: .linkedIn)
            blog = try container.decodeIfPresent(String.self, forKey: .blog)
            avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            cardLink = try container.decode(String.self, forKey: .cardLink)
        } else {
            // v1: 정체성 필드는 ownerName 하나뿐 — 나머지는 빈 값으로 채운다.
            name = try container.decode(String.self, forKey: .ownerName)
            nickname = ""
            part = ""
            generation = ""
            university = ""
            email = nil
            github = nil
            linkedIn = nil
            blog = nil
            avatarURL = nil
            cardLink = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardID, forKey: .cardID)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(part, forKey: .part)
        try container.encode(generation, forKey: .generation)
        try container.encode(university, forKey: .university)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(github, forKey: .github)
        try container.encodeIfPresent(linkedIn, forKey: .linkedIn)
        try container.encodeIfPresent(blog, forKey: .blog)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encode(cardLink, forKey: .cardLink)
        try container.encodeIfPresent(usdzURL, forKey: .usdzURL)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(version, forKey: .version)
    }

    // MARK: - Function

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> ExchangePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExchangePayload.self, from: data)
    }
}
