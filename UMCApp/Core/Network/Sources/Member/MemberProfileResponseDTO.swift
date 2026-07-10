//
//  MemberProfileResponseDTO.swift
//  CoreNetwork
//
//  `GET /api/v1/member/me` 정본 응답 DTO 모음.
//  - Auth `MemberMeResponseDTO`, Home `MyProfileResponseDTO`, MyPage `MyPageProfileDTO`
//    3개 파이프라인이 각자 필요로 하던 필드의 합집합을 한 파일에 모은다.
//  - 서버 응답 숫자 필드는 모두 `String`으로 보존하며, 도메인 변환 시점에만 `Int`로 환원한다.
//

import Foundation
import UMCFoundation

// MARK: - Main Response

/// 내 프로필 조회 응답 DTO
///
/// 부트스트랩 승인 판정(Auth) + 시즌/세대 카드 구성(Home) + 프로필 화면 전체 항목(MyPage)에
/// 필요한 필드를 모두 디코딩한다. 서버 정수 필드(멤버/학교/지부 ID, 기수 번호)는 절대규칙 #2에
/// 따라 `String`으로 통일한다.
public struct MemberProfileResponseDTO: Codable {

    // MARK: - Property

    public let id: String
    public let name: String
    public let nickname: String
    public let email: String
    public let schoolId: String
    public let schoolName: String
    public let profileImageLink: String?
    public let profile: MemberProfileExternalLinksDTO?
    public let status: MemberStatus
    public let roles: [MemberProfileRoleDTO]
    public let challengerRecords: [MemberProfileChallengerRecordDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nickname
        case email
        case schoolId
        case schoolName
        case profileImageLink
        case profile
        case status
        case roles
        case challengerRecords
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        email = container.decodeFlexibleStringOrEmpty(forKey: .email)
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)
        profile = try container.decodeIfPresent(
            MemberProfileExternalLinksDTO.self,
            forKey: .profile
        )
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status) ?? .active
        roles = try container.decodeIfPresent([MemberProfileRoleDTO].self, forKey: .roles) ?? []
        challengerRecords = try container.decodeIfPresent(
            [MemberProfileChallengerRecordDTO].self,
            forKey: .challengerRecords
        ) ?? []
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(email, forKey: .email)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageLink, forKey: .profileImageLink)
        try container.encodeIfPresent(profile, forKey: .profile)
        try container.encode(status, forKey: .status)
        try container.encode(roles, forKey: .roles)
        try container.encode(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - MemberProfileExternalLinksDTO

/// 프로필 응답의 `profile` 하위 객체 (외부 링크).
public struct MemberProfileExternalLinksDTO: Codable {

    // MARK: - Property

    public let id: String
    public let linkedIn: String?
    public let instagram: String?
    public let github: String?
    public let blog: String?
    public let personal: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case linkedIn
        case instagram
        case github
        case blog
        case personal
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        linkedIn = try container.decodeFlexibleStringIfPresent(forKey: .linkedIn)
        instagram = try container.decodeFlexibleStringIfPresent(forKey: .instagram)
        github = try container.decodeFlexibleStringIfPresent(forKey: .github)
        blog = try container.decodeFlexibleStringIfPresent(forKey: .blog)
        personal = try container.decodeFlexibleStringIfPresent(forKey: .personal)
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(linkedIn, forKey: .linkedIn)
        try container.encodeIfPresent(instagram, forKey: .instagram)
        try container.encodeIfPresent(github, forKey: .github)
        try container.encodeIfPresent(blog, forKey: .blog)
        try container.encodeIfPresent(personal, forKey: .personal)
    }
}

// MARK: - MemberProfileRoleDTO

/// 프로필 응답의 `roles[]` 항목 DTO (운영진 역할 정보).
public struct MemberProfileRoleDTO: Codable {

    // MARK: - Property

    public let id: String
    public let challengerId: String
    public let roleType: ManagementTeam
    public let organizationType: OrganizationType
    public let organizationId: String?
    public let responsiblePart: String?
    public let gisu: String
    public let gisuId: String

    private enum CodingKeys: String, CodingKey {
        case id
        case challengerId
        case roleType
        case organizationType
        case organizationId
        case responsiblePart
        case gisu
        case gisuId
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        challengerId = container.decodeFlexibleStringOrEmpty(forKey: .challengerId)
        // roleType/organizationType 누락 시 Auth 원본 관례를 따라 challenger/central로 폴백한다
        // (중앙 운영진은 지부/학교 무소속이 기본값이라는 서버 계약과 일치).
        roleType = try container.decodeIfPresent(ManagementTeam.self, forKey: .roleType)
            ?? .challenger
        organizationType = try container.decodeIfPresent(
            OrganizationType.self,
            forKey: .organizationType
        ) ?? .central
        organizationId = container.decodeFlexibleStringOrNil(forKey: .organizationId)
        responsiblePart = try container.decodeIfPresent(String.self, forKey: .responsiblePart)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
        gisuId = container.decodeFlexibleStringOrEmpty(forKey: .gisuId)
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(roleType, forKey: .roleType)
        try container.encode(organizationType, forKey: .organizationType)
        try container.encodeIfPresent(organizationId, forKey: .organizationId)
        try container.encodeIfPresent(responsiblePart, forKey: .responsiblePart)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
    }
}

// MARK: - MemberProfileChallengerRecordDTO

/// 프로필 응답의 `challengerRecords[]` 항목 DTO (기수별 챌린저 활동 기록).
public struct MemberProfileChallengerRecordDTO: Codable {

    // MARK: - Property

    public let challengerId: String
    public let memberId: String?
    public let gisu: String
    public let gisuId: String
    public let chapterId: String?
    public let chapterName: String?
    public let part: String
    public let schoolId: String
    public let schoolName: String
    public let name: String?
    public let nickname: String?
    public let email: String?
    public let profileImageLink: String?
    public let status: MemberStatus
    public let challengerPoints: [MemberProfileChallengerPointDTO]

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisu
        case gisuId
        case chapterId
        case chapterName
        case part
        case schoolId
        case schoolName
        case name
        case nickname
        case email
        case profileImageLink
        case status
        case challengerPoints
    }

    /// `status` 키 누락 시 폴백으로 조회하는 레거시 키 (MyPage 원본 로직 이식).
    private enum FallbackCodingKeys: String, CodingKey {
        case memberStatus
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = container.decodeFlexibleStringOrEmpty(forKey: .challengerId)
        memberId = container.decodeFlexibleStringOrNil(forKey: .memberId)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
        gisuId = container.decodeFlexibleStringOrEmpty(forKey: .gisuId)
        chapterId = container.decodeFlexibleStringOrNil(forKey: .chapterId)
        chapterName = try container.decodeIfPresent(String.self, forKey: .chapterName)
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        email = container.decodeFlexibleStringOrNil(forKey: .email)
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)

        let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status)
            ?? fallbackContainer.decodeIfPresent(MemberStatus.self, forKey: .memberStatus)
            ?? .active

        challengerPoints = try container.decodeIfPresent(
            [MemberProfileChallengerPointDTO].self,
            forKey: .challengerPoints
        ) ?? decoder.decodeMemberProfilePointsArrayFallback() ?? []
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encodeIfPresent(memberId, forKey: .memberId)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encodeIfPresent(chapterId, forKey: .chapterId)
        try container.encodeIfPresent(chapterName, forKey: .chapterName)
        try container.encode(part, forKey: .part)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(profileImageLink, forKey: .profileImageLink)
        try container.encode(status, forKey: .status)
        try container.encode(challengerPoints, forKey: .challengerPoints)
    }
}

// MARK: - MemberProfileChallengerPointDTO

/// 챌린저 기록의 `challengerPoints[]` 항목 DTO (가점/감점 이력).
///
/// 서버 응답이 `challengerPoints` 키 대신 `points` 키로 내려오는 fallback 케이스도
/// `MemberProfileChallengerRecordDTO` 디코더에서 처리한다.
public struct MemberProfileChallengerPointDTO: Codable {

    // MARK: - Property

    public let id: String
    public let pointType: String
    public let point: Double
    public let description: String
    public let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case pointType
        case point
        case description
        case createdAt
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        pointType = try container.decode(String.self, forKey: .pointType)
        point = try container.decodeDoubleFlexible(forKey: .point)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pointType, forKey: .pointType)
        try container.encode(point, forKey: .point)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Dynamic Coding Key (Fallback)

private struct MemberProfileDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension Decoder {
    /// `challengerPoints` 키가 누락되었을 때 `points` 키를 fallback으로 디코딩한다
    /// (Home/MyPage의 동일 폴백 로직 이식).
    func decodeMemberProfilePointsArrayFallback() -> [MemberProfileChallengerPointDTO]? {
        guard let container = try? self.container(keyedBy: MemberProfileDynamicCodingKey.self),
              let key = MemberProfileDynamicCodingKey(stringValue: "points") else {
            return nil
        }
        return try? container.decodeIfPresent(
            [MemberProfileChallengerPointDTO].self,
            forKey: key
        )
    }
}
