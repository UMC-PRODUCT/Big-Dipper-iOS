//
//  CardResponseDTO.swift
//  BusinessCardData
//
//  Created by JEONG on 8/30/26.
//

import Foundation
import UMCFoundation

/// 명함 전용 공개 응답 (`GET /api/v1/cards/members/{memberId}`).
///
/// `GET /api/v1/cards/{slug}` 와 **같은 DTO·같은 마스킹 규칙**이다 — `email` 은 서로
/// 담은 사이(`isMutual`)일 때만 실린다. 판단은 서버가 하고 앱은 받은 대로 쓴다.
///
/// 아직 배선하지 않는다. `PeerCardRepository` 가 `/member/profile/{id}` 에 얹혀 있어
/// 기수·파트가 보장되지 않는 것이 「운영진 · 0기」 명함(#1223)의 근본 원인이고, 이 응답이
/// 그 전환의 대상이다.
public struct CardResponseDTO: Codable, Equatable, Sendable {

    // MARK: - Property

    public let memberId: String
    public let name: String
    public let nickname: String
    /// 서버 원문 그대로 (``MyCard/partRaw`` 규약).
    public let part: String
    public let generation: String
    public let schoolName: String
    public let profileImageURL: String?
    public let email: String?
    public let github: String?
    public let blog: String?
    public let linkedIn: String?
    public let instagram: String?
    public let personal: String?
    public let isMutual: Bool

    // MARK: - Init

    public init(
        memberId: String,
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
        isMutual: Bool = false
    ) {
        self.memberId = memberId
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
        self.isMutual = isMutual
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case memberId, name, nickname, part, generation, schoolName
        case profileImageURL, email, github, blog, linkedIn, instagram, personal, isMutual
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decodeFlexibleString(forKey: .memberId)
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
        isMutual = try container.decodeBoolFlexibleIfPresent(forKey: .isMutual) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
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
        try container.encode(isMutual, forKey: .isMutual)
    }
}
