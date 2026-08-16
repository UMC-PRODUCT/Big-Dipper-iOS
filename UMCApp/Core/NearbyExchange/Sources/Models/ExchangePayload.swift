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
    /// 프로필 딥링크 (`umc://card/{memberId}`). 수신 측이 프로필 API로 최신화할 때 쓴다.
    /// **memberId의 유일한 운반 수단** — 수신 측은 이 값을 파싱해 정체성을 복원한다.
    public let cardLink: String
    /// 3D 명함 에셋. v2에서 옵셔널로 완화 — 3D 명함은 후속 트랙.
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

/// BLE 2단계 광고 페이로드 (PRD Q2 결정: Service UUID 16B + cardUUID prefix 8B + version 1B + flags 1B)
/// 풀 JSON은 GATT 또는 서버 fetch로 수신.
public struct BLEAdvertisementPayload: Sendable {

    // MARK: - Property

    public let cardUUIDPrefix: Data   // 8 bytes
    public let version: UInt8         // 1 byte
    public let flags: UInt8           // 1 byte (기수 6bit, 파트 4bit)

    // MARK: - Init

    public init(cardUUIDPrefix: Data, version: UInt8, flags: UInt8) {
        self.cardUUIDPrefix = cardUUIDPrefix
        self.version = version
        self.flags = flags
    }
}
