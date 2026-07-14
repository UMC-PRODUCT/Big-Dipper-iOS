//
//  ChallengerSearchOffsetDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import UMCFoundation

// MARK: - ChallengerSearchOffsetResultDTO

/// 챌린저 오프셋 검색 결과 DTO
///
/// `GET /api/v1/challenger/search/offset`
struct ChallengerSearchOffsetResultDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let page: ChallengerSearchOffsetPageDTO

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case page
    }

    // MARK: - Init

    init(page: ChallengerSearchOffsetPageDTO) {
        self.page = page
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(
            ChallengerSearchOffsetPageDTO.self,
            forKey: .page
        ) ?? .empty
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
    }
}

// MARK: - ChallengerSearchOffsetPageDTO

/// 오프셋 페이지 메타 + 항목 목록
struct ChallengerSearchOffsetPageDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let content: [ChallengerSearchOffsetItemDTO]
    let page: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrevious: Bool

    // MARK: - Empty

    /// `page` 필드 부재 시 사용할 빈 페이지.
    static let empty = ChallengerSearchOffsetPageDTO(
        content: [],
        page: 0,
        size: 0,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
        hasPrevious: false
    )

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case content
        case page
        case size
        case totalElements
        case totalPages
        case hasNext
        case hasPrevious
    }

    // MARK: - Init

    init(
        content: [ChallengerSearchOffsetItemDTO],
        page: Int,
        size: Int,
        totalElements: Int,
        totalPages: Int,
        hasNext: Bool,
        hasPrevious: Bool
    ) {
        self.content = content
        self.page = page
        self.size = size
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(
            [ChallengerSearchOffsetItemDTO].self,
            forKey: .content
        ) ?? []
        page = try container.decodeIntFlexibleIfPresent(forKey: .page) ?? 0
        size = try container.decodeIntFlexibleIfPresent(forKey: .size) ?? 0
        totalElements = try container.decodeIntFlexibleIfPresent(forKey: .totalElements) ?? 0
        totalPages = try container.decodeIntFlexibleIfPresent(forKey: .totalPages) ?? 0
        hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
        hasPrevious = try container.decodeBoolFlexibleIfPresent(forKey: .hasPrevious) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(page, forKey: .page)
        try container.encode(size, forKey: .size)
        try container.encode(totalElements, forKey: .totalElements)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(hasNext, forKey: .hasNext)
        try container.encode(hasPrevious, forKey: .hasPrevious)
    }
}

// MARK: - ChallengerSearchOffsetItemDTO

/// 검색 결과 단일 챌린저 항목
struct ChallengerSearchOffsetItemDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerId: String
    let memberId: String
    let gisuId: String
    /// 기수 표시 번호(예: 9). 식별자가 아닌 표시·정렬용 수치라 `Int`.
    let generation: Int?
    let gisu: Int?
    let part: String
    let name: String
    let nickname: String
    let schoolName: String
    let pointSum: Double
    let profileImageURL: String?
    let roleTypes: [ManagementTeam]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisuId
        case generation
        case gisu
        case part
        case name
        case nickname
        case schoolName
        case pointSum
        case profileImageURL = "profileImageLink"
        case roleTypes
    }

    // MARK: - Init

    init(
        challengerId: String,
        memberId: String,
        gisuId: String,
        generation: Int?,
        gisu: Int?,
        part: String,
        name: String,
        nickname: String,
        schoolName: String,
        pointSum: Double,
        profileImageURL: String?,
        roleTypes: [ManagementTeam]
    ) {
        self.challengerId = challengerId
        self.memberId = memberId
        self.gisuId = gisuId
        self.generation = generation
        self.gisu = gisu
        self.part = part
        self.name = name
        self.nickname = nickname
        self.schoolName = schoolName
        self.pointSum = pointSum
        self.profileImageURL = profileImageURL
        self.roleTypes = roleTypes
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeFlexibleStringIfPresent(forKey: .challengerId) ?? ""
        memberId = try container.decodeFlexibleStringIfPresent(forKey: .memberId) ?? ""
        gisuId = try container.decodeFlexibleStringIfPresent(forKey: .gisuId) ?? ""
        generation = try container.decodeIntFlexibleIfPresent(forKey: .generation)
        gisu = try container.decodeIntFlexibleIfPresent(forKey: .gisu)
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        pointSum = try container.decodeDoubleFlexibleIfPresent(forKey: .pointSum) ?? 0
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        let rawRoleTypes = try container.decodeIfPresent([String].self, forKey: .roleTypes) ?? []
        roleTypes = rawRoleTypes.compactMap(ManagementTeam.init(rawValue:))
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encodeIfPresent(generation, forKey: .generation)
        try container.encodeIfPresent(gisu, forKey: .gisu)
        try container.encode(part, forKey: .part)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encode(pointSum, forKey: .pointSum)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(roleTypes.map(\.rawValue), forKey: .roleTypes)
    }
}
