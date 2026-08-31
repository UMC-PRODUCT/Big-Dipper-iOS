//
//  CardExchangeItemDTO.swift
//  BusinessCardData
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import UMCFoundation

/// 명함첩 항목 한 장 (`GET /api/v1/cards/exchanges` 의 `content` 원소).
///
/// 서버 정수(`cardMemberId`·`generation`)는 전 레이어 `String` 이다 (절대 규칙 #2).
/// 서버 `JacksonConfig` 가 `WRITE_NUMBERS_AS_STRINGS` 를 전역 활성화해 두었지만, 설정이
/// 바뀌어 숫자로 내려와도 흡수해야 하므로 `decodeFlexibleString` 을 쓴다.
///
/// - Important: `email` 의 `null` 은 **값이다.** 상대가 나를 명함첩에서 지우면 서버가
///   `isMutual` 을 거짓으로 두고 이메일을 내리지 않는다. 로컬 캐시로 폴백하면 지워진
///   이메일이 계속 보이므로, 이 `nil` 을 그대로 아래까지 나른다.
public struct CardExchangeItemDTO: Codable, Equatable, Sendable {

    // MARK: - Property

    public let cardMemberId: String
    public let name: String
    public let nickname: String
    /// 서버 원문 그대로. `UMCPartType` 파싱은 매핑에서 한다 — 못 읽는 값을 `ADMIN` 으로
    /// 눌러 담으면 원본이 영영 사라진다 (``MyCard/partRaw`` 규약).
    public let part: String
    public let generation: String
    public let schoolName: String
    public let profileImageURL: String?
    /// `isMutual == false` 면 `null`. 폴백 금지 (프라이버시).
    public let email: String?
    public let github: String?
    public let blog: String?
    public let linkedIn: String?
    public let instagram: String?
    public let personal: String?
    /// `"QR"` · `"NEARBY"` · `"BULK"` …. 모르는 값도 그대로 담는다 —
    /// ``ExchangeMethod`` 가 `.unknown` 으로 흡수한다.
    public let source: String
    public let exchangedAt: String
    /// 상대도 나를 담았는지. 이메일 표시 판단에는 쓰지 않는다 (판단 주체는 서버 하나다).
    public let isMutual: Bool

    // MARK: - Init

    public init(
        cardMemberId: String,
        name: String,
        nickname: String,
        part: String,
        generation: String,
        schoolName: String,
        profileImageURL: String? = nil,
        email: String? = nil,
        github: String? = nil,
        blog: String? = nil,
        linkedIn: String? = nil,
        instagram: String? = nil,
        personal: String? = nil,
        source: String,
        exchangedAt: String,
        isMutual: Bool = false
    ) {
        self.cardMemberId = cardMemberId
        self.name = name
        self.nickname = nickname
        self.part = part
        self.generation = generation
        self.schoolName = schoolName
        self.profileImageURL = profileImageURL
        self.email = email
        self.github = github
        self.blog = blog
        self.linkedIn = linkedIn
        self.instagram = instagram
        self.personal = personal
        self.source = source
        self.exchangedAt = exchangedAt
        self.isMutual = isMutual
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case cardMemberId, name, nickname, part, generation, schoolName
        case profileImageURL, email, github, blog, linkedIn, instagram, personal
        case source, exchangedAt, isMutual
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardMemberId = try container.decodeFlexibleString(forKey: .cardMemberId)
        name = container.decodeFlexibleStringOrEmpty(forKey: .name)
        nickname = container.decodeFlexibleStringOrEmpty(forKey: .nickname)
        part = container.decodeFlexibleStringOrEmpty(forKey: .part)
        generation = container.decodeFlexibleStringOrEmpty(forKey: .generation)
        schoolName = container.decodeFlexibleStringOrEmpty(forKey: .schoolName)
        profileImageURL = container.decodeFlexibleStringOrNil(forKey: .profileImageURL)
        email = container.decodeFlexibleStringOrNil(forKey: .email)
        github = container.decodeFlexibleStringOrNil(forKey: .github)
        blog = container.decodeFlexibleStringOrNil(forKey: .blog)
        linkedIn = container.decodeFlexibleStringOrNil(forKey: .linkedIn)
        instagram = container.decodeFlexibleStringOrNil(forKey: .instagram)
        personal = container.decodeFlexibleStringOrNil(forKey: .personal)
        source = container.decodeFlexibleStringOrEmpty(forKey: .source)
        exchangedAt = container.decodeFlexibleStringOrEmpty(forKey: .exchangedAt)
        isMutual = try container.decodeBoolFlexibleIfPresent(forKey: .isMutual) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardMemberId, forKey: .cardMemberId)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(part, forKey: .part)
        try container.encode(generation, forKey: .generation)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(github, forKey: .github)
        try container.encodeIfPresent(blog, forKey: .blog)
        try container.encodeIfPresent(linkedIn, forKey: .linkedIn)
        try container.encodeIfPresent(instagram, forKey: .instagram)
        try container.encodeIfPresent(personal, forKey: .personal)
        try container.encode(source, forKey: .source)
        try container.encode(exchangedAt, forKey: .exchangedAt)
        try container.encode(isMutual, forKey: .isMutual)
    }
}
