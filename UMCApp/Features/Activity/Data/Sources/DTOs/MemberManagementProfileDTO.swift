//
//  MemberManagementProfileDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import UMCFoundation

// MARK: - MemberManagementProfileDTO

/// 멤버 프로필 응답 DTO (멤버 관리 화면용 · 리치 필드)
///
/// `GET /api/v1/member/profile/{memberId}`
///
/// 같은 엔드포인트를 ``MemberProfileDTO``(챌린저 ID 해석 전용, `challengerRecords` 만)도
/// 디코딩하지만, 멤버 관리에는 이름·역할·기수별 포인트가 필요해 필드가 더 많은 별도 DTO 로 나눴습니다.
/// 서버 식별자는 전 레이어 `String` 통일 규칙에 따라 `String` 으로 디코딩합니다(핵심 규칙 #2).
struct MemberManagementProfileDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let id: String
    let name: String
    let nickname: String
    let schoolName: String
    let profileImageURL: String?
    let roles: [MemberManagementRoleDTO]
    let challengerRecords: [MemberManagementChallengerRecordDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nickname
        case schoolName
        case profileImageURL = "profileImageLink"
        case roles
        case challengerRecords
    }

    // MARK: - Init

    init(
        id: String,
        name: String,
        nickname: String,
        schoolName: String,
        profileImageURL: String?,
        roles: [MemberManagementRoleDTO],
        challengerRecords: [MemberManagementChallengerRecordDTO]
    ) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.schoolName = schoolName
        self.profileImageURL = profileImageURL
        self.roles = roles
        self.challengerRecords = challengerRecords
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleStringIfPresent(forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        roles = try container.decodeIfPresent(
            [MemberManagementRoleDTO].self,
            forKey: .roles
        ) ?? []
        challengerRecords = try container.decodeIfPresent(
            [MemberManagementChallengerRecordDTO].self,
            forKey: .challengerRecords
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(roles, forKey: .roles)
        try container.encode(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - MemberManagementRoleDTO

/// 멤버의 운영 역할 DTO
struct MemberManagementRoleDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerId: String?
    let roleType: ManagementTeam

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case roleType
    }

    // MARK: - Init

    init(challengerId: String?, roleType: ManagementTeam) {
        self.challengerId = challengerId
        self.roleType = roleType
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeFlexibleStringIfPresent(forKey: .challengerId)
        // 미지의 역할 문자열은 디코딩을 실패시키지 않고 challenger 로 폴백한다(서버가 새 역할을
        // 추가해도 안전). `decodeIfPresent(ManagementTeam.self)` 는 미지의 rawValue 에서 throw
        // 하므로 raw String 으로 받아 매핑한다.
        let rawRoleType = try container.decodeIfPresent(String.self, forKey: .roleType)
        roleType = rawRoleType.flatMap(ManagementTeam.init(rawValue:)) ?? .challenger
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(challengerId, forKey: .challengerId)
        try container.encode(roleType, forKey: .roleType)
    }
}

// MARK: - MemberManagementChallengerRecordDTO

/// 멤버의 기수별 챌린저 활동 레코드 DTO
struct MemberManagementChallengerRecordDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerId: String
    let memberId: String
    /// 기수 표시 번호(예: 9). 식별자가 아닌 표시·정렬용 수치라 `Int`.
    let gisu: Int
    let gisuId: String
    let part: String
    let challengerPoints: [MemberManagementPointDTO]
    /// 서버가 `points` 키로 내려주는 폴백 포인트(챌린저 포인트가 비었을 때 사용).
    let fallbackPoints: [MemberManagementPointDTO]

    /// 챌린저 포인트가 비어 있으면 폴백 포인트를 사용합니다.
    var resolvedPoints: [MemberManagementPointDTO] {
        challengerPoints.isEmpty ? fallbackPoints : challengerPoints
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisu
        case gisuId
        case part
        case challengerPoints
        case fallbackPoints = "points"
    }

    // MARK: - Init

    init(
        challengerId: String,
        memberId: String,
        gisu: Int,
        gisuId: String,
        part: String,
        challengerPoints: [MemberManagementPointDTO],
        fallbackPoints: [MemberManagementPointDTO]
    ) {
        self.challengerId = challengerId
        self.memberId = memberId
        self.gisu = gisu
        self.gisuId = gisuId
        self.part = part
        self.challengerPoints = challengerPoints
        self.fallbackPoints = fallbackPoints
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeFlexibleStringIfPresent(forKey: .challengerId) ?? ""
        memberId = try container.decodeFlexibleStringIfPresent(forKey: .memberId) ?? ""
        gisu = try container.decodeIntFlexibleIfPresent(forKey: .gisu) ?? 0
        gisuId = try container.decodeFlexibleStringIfPresent(forKey: .gisuId) ?? ""
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        challengerPoints = try container.decodeIfPresent(
            [MemberManagementPointDTO].self,
            forKey: .challengerPoints
        ) ?? []
        fallbackPoints = try container.decodeIfPresent(
            [MemberManagementPointDTO].self,
            forKey: .fallbackPoints
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encode(part, forKey: .part)
        try container.encode(challengerPoints, forKey: .challengerPoints)
        try container.encode(fallbackPoints, forKey: .fallbackPoints)
    }
}

// MARK: - MemberManagementPointDTO

/// 단일 상벌점 항목 DTO
struct MemberManagementPointDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let id: String
    let pointType: String
    let point: Double
    let description: String
    let createdAt: String

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id
        case pointType
        case point
        case description
        case createdAt
    }

    // MARK: - Init

    init(
        id: String,
        pointType: String,
        point: Double,
        description: String,
        createdAt: String
    ) {
        self.id = id
        self.pointType = pointType
        self.point = point
        self.description = description
        self.createdAt = createdAt
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleStringIfPresent(forKey: .id) ?? ""
        pointType = try container.decodeIfPresent(String.self, forKey: .pointType) ?? ""
        point = try container.decodeDoubleFlexibleIfPresent(forKey: .point) ?? 0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pointType, forKey: .pointType)
        try container.encode(point, forKey: .point)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
