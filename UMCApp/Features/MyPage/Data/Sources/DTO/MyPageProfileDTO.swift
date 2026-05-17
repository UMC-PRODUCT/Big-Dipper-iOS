//
//  MyPageProfileDTO.swift
//  MyPageData
//
//  마이페이지 프로필 조회/수정 응답 DTO 모음.
//  - 메인 응답(MyPageProfileResponseDTO)과 그 하위 컬렉션 DTO(역할/기록/포인트/외부링크)를 한 파일에 모은다.
//  - 서버 응답 숫자 필드는 모두 `String`으로 보존하며, 도메인 변환 시점에만 `Int`로 환원한다.
//

import Foundation
import UMCFoundation
import CoreEnum
import CoreDomain
import MyPageDomain

// MARK: - Main Response

/// 마이페이지 프로필 조회/수정 응답 DTO
///
/// 다음 엔드포인트의 `result` 본문을 매핑합니다.
/// - `GET /api/v1/member/me` — 내 프로필 조회
/// - `GET /api/v1/member/profile/{memberId}` — 특정 멤버 프로필 조회
/// - `PATCH /api/v1/member` — 프로필 이미지 ID 수정 응답
/// - `PATCH /api/v1/member/profile/links` — 외부 링크 수정 응답
public struct MyPageProfileResponseDTO: Codable {
    let id: String
    let name: String
    let nickname: String
    let email: String
    let schoolId: String
    let schoolName: String
    let profileImageLink: String?
    let profile: MyPageProfileExternalLinksDTO?
    let status: MemberStatus
    let roles: [MyPageRoleDTO]
    let challengerRecords: [MyPageChallengerRecordDTO]?

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decode(String.self, forKey: .nickname)
        email = try container.decodeFlexibleStringIfPresent(forKey: .email) ?? ""
        schoolId = try container.decodeFlexibleString(forKey: .schoolId)
        schoolName = try container.decode(String.self, forKey: .schoolName)
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)
        profile = try container.decodeIfPresent(
            MyPageProfileExternalLinksDTO.self,
            forKey: .profile
        )
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status) ?? .active
        roles = try container.decodeIfPresent([MyPageRoleDTO].self, forKey: .roles) ?? []
        challengerRecords = try container.decodeIfPresent(
            [MyPageChallengerRecordDTO].self,
            forKey: .challengerRecords
        )
    }

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
        try container.encodeIfPresent(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - External Links

/// `/api/v1/member/me` 응답의 `profile` 하위 객체
public struct MyPageProfileExternalLinksDTO: Codable {
    let id: String
    let linkedIn: String?
    let instagram: String?
    let github: String?
    let blog: String?
    let personal: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case linkedIn
        case instagram
        case github
        case blog
        case personal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleStringIfPresent(forKey: .id) ?? ""
        linkedIn = try container.decodeFlexibleStringIfPresent(forKey: .linkedIn)
        instagram = try container.decodeFlexibleStringIfPresent(forKey: .instagram)
        github = try container.decodeFlexibleStringIfPresent(forKey: .github)
        blog = try container.decodeFlexibleStringIfPresent(forKey: .blog)
        personal = try container.decodeFlexibleStringIfPresent(forKey: .personal)
    }

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

// MARK: - Role

/// 프로필 응답의 `roles[]` 항목 DTO
///
/// 운영진 역할(중앙/지부/교내) 정보를 나타냅니다. `roleType`은 `ManagementTeam` enum에,
/// `organizationType`은 `OrganizationType` enum에 매핑됩니다.
public struct MyPageRoleDTO: Codable {
    let id: String
    let challengerId: String
    let roleType: ManagementTeam
    let organizationType: OrganizationType
    let organizationId: String?
    let responsiblePart: String?
    let gisu: String?
    let gisuId: String

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        challengerId = try container.decodeFlexibleString(forKey: .challengerId)
        roleType = try container.decode(ManagementTeam.self, forKey: .roleType)
        organizationType = try container.decode(OrganizationType.self, forKey: .organizationType)
        organizationId = try container.decodeFlexibleStringIfPresent(forKey: .organizationId)
        responsiblePart = try container.decodeIfPresent(String.self, forKey: .responsiblePart)
        gisu = try container.decodeFlexibleStringIfPresent(forKey: .gisu)
        gisuId = try container.decodeFlexibleString(forKey: .gisuId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(roleType, forKey: .roleType)
        try container.encode(organizationType, forKey: .organizationType)
        try container.encodeIfPresent(organizationId, forKey: .organizationId)
        try container.encodeIfPresent(responsiblePart, forKey: .responsiblePart)
        try container.encodeIfPresent(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
    }
}

// MARK: - Challenger Record

/// 프로필 응답의 `challengerRecords[]` 항목 DTO
///
/// 한 멤버가 활동한 기수별 챌린저 기록을 나타냅니다.
/// `gisu`(기수)와 `part`(파트 식별 문자열, `UMCPartType.apiValue`)로 구분되며,
/// 같은 멤버라도 기수마다 별도 record로 누적됩니다.
public struct MyPageChallengerRecordDTO: Codable {
    let challengerId: String
    let memberId: String
    let gisu: String
    let chapterName: String?
    let part: String
    let challengerPoints: [MyPageChallengerPointDTO]
    let name: String
    let nickname: String
    let email: String?
    let schoolId: String
    let schoolName: String
    let profileImageLink: String?
    let status: MemberStatus

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisu
        case chapterName
        case part
        case challengerPoints
        case name
        case nickname
        case email
        case schoolId
        case schoolName
        case profileImageLink
        case status
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case memberStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeFlexibleString(forKey: .challengerId)
        memberId = try container.decodeFlexibleString(forKey: .memberId)
        gisu = try container.decodeFlexibleString(forKey: .gisu)
        chapterName = try container.decodeIfPresent(String.self, forKey: .chapterName)
        part = try container.decode(String.self, forKey: .part)
        challengerPoints = try container.decodeIfPresent([MyPageChallengerPointDTO].self, forKey: .challengerPoints)
            ?? decoder.decodeMyPagePointsArrayFallback()
            ?? []
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decode(String.self, forKey: .nickname)
        email = try container.decodeFlexibleStringIfPresent(forKey: .email)
        schoolId = try container.decodeFlexibleString(forKey: .schoolId)
        schoolName = try container.decode(String.self, forKey: .schoolName)
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)
        let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status)
            ?? fallbackContainer.decodeIfPresent(MemberStatus.self, forKey: .memberStatus)
            ?? .active
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(gisu, forKey: .gisu)
        try container.encodeIfPresent(chapterName, forKey: .chapterName)
        try container.encode(part, forKey: .part)
        try container.encode(challengerPoints, forKey: .challengerPoints)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageLink, forKey: .profileImageLink)
        try container.encode(status, forKey: .status)
    }
}

// MARK: - Challenger Point

/// 챌린저 기록의 `challengerPoints[]` 항목 DTO
///
/// 활동 가점/감점 등 포인트 이력을 나타냅니다. 서버 응답이 `challengerPoints` 키
/// 대신 `points` 키로 내려오는 fallback 케이스도 `MyPageChallengerRecordDTO` 디코더에서 처리됩니다.
public struct MyPageChallengerPointDTO: Codable {
    let id: String
    let pointType: String
    let point: Double
    let description: String
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case pointType
        case point
        case description
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        pointType = try container.decode(String.self, forKey: .pointType)
        point = try container.decodeFlexibleDouble(forKey: .point)
        description = try container.decode(String.self, forKey: .description)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

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

private struct MyPageDynamicCodingKey: CodingKey {
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
    /// `challengerPoints` 키가 누락되었을 때 `points` 키를 fallback으로 디코딩합니다.
    func decodeMyPagePointsArrayFallback() throws -> [MyPageChallengerPointDTO]? {
        let container = try self.container(keyedBy: MyPageDynamicCodingKey.self)
        guard let key = MyPageDynamicCodingKey(stringValue: "points") else {
            return nil
        }
        return try container.decodeIfPresent([MyPageChallengerPointDTO].self, forKey: key)
    }
}

// MARK: - Domain Mapping

public extension MyPageProfileResponseDTO {
    /// 프로필 응답을 도메인 `ProfileData`로 변환합니다.
    func toProfileData() -> ProfileData {
        let records = challengerRecords ?? []
        let visibleRecords = records.filter { UMCPartType(apiValue: $0.part) != .admin }
        let latestRecord = visibleRecords.max { $0.gisu.intValue < $1.gisu.intValue }
            ?? records.max { $0.gisu.intValue < $1.gisu.intValue }
        let latestRole = roles.max { ($0.gisu?.intValue ?? 0) < ($1.gisu?.intValue ?? 0) }
        let profileLinks = profileLinks()

        let fallbackPart = latestRole?.responsiblePart
            .flatMap { UMCPartType(apiValue: $0) } ?? .admin

        let challengerInfo = ChallengerInfo(
            memberId: id,
            gen: latestRecord?.gisu.intValue ?? latestRole?.gisu?.intValue ?? 0,
            name: latestRecord?.name ?? name,
            nickname: latestRecord?.nickname ?? nickname,
            schoolName: latestRecord?.schoolName ?? schoolName,
            profileImage: latestRecord?.profileImageLink?.nonEmpty ?? profileImageLink?.nonEmpty,
            part: UMCPartType(apiValue: latestRecord?.part ?? "") ?? fallbackPart
        )

        let logs = activityLogs(records: records)

        return ProfileData(
            challengeId: latestRecord?.challengerId.intValue ?? latestRole?.challengerId.intValue ?? 0,
            challangerInfo: challengerInfo,
            socialConnections: [],
            activityLogs: logs,
            profileLink: profileLinks
        )
    }

    /// Notice 상세 작성자 표시용 프로필 요약 모델을 생성합니다.
    func toMemberProfileSummary() -> MemberProfileSummary {
        let sortedRoles = roles
            .compactMap {
                (
                    role: $0,
                    generation: Int($0.gisu ?? $0.gisuId) ?? 0,
                    level: $0.roleType.level
                )
            }
            .sorted {
                if $0.level == $1.level {
                    return $0.generation > $1.generation
                }
                return $0.level > $1.level
            }

        let selectedRole = sortedRoles.first
        let latestRecordGeneration = challengerRecords?
            .compactMap { Int($0.gisu) }
            .max() ?? 0
        let latestRecord = (challengerRecords ?? [])
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
            .first
        let generation = selectedRole?.generation ?? latestRecordGeneration
        let roleName = selectedRole?.role.roleType.korean ?? "챌린저"
        let organizationName = latestRecord?.chapterName?.nonEmpty ?? latestRecord?.schoolName.nonEmpty

        return MemberProfileSummary(
            memberId: id,
            name: latestRecordName(),
            nickname: latestRecordNickname(),
            generation: generation,
            organizationName: organizationName,
            roleName: roleName,
            profileImageURL: profileImageLink
        )
    }
}

private extension MyPageProfileResponseDTO {
    func activityLogs(records: [MyPageChallengerRecordDTO]) -> [ActivityLog] {
        let roleLogs = roles.map { role in
            ActivityLog(
                part: role.responsiblePart.flatMap { UMCPartType(apiValue: $0) } ?? .admin,
                generation: role.gisu?.intValue ?? 0,
                role: role.roleType
            )
        }

        let challengerLogs = records.compactMap { record -> ActivityLog? in
            guard let part = UMCPartType(apiValue: record.part), part != .admin else {
                return nil
            }

            return ActivityLog(
                part: part,
                generation: record.gisu.intValue,
                role: .challenger
            )
        }

        let allLogs = roleLogs + challengerLogs
        let merged = mergeAdminLogs(allLogs)

        return merged.sorted { lhs, rhs in
            if lhs.generation == rhs.generation {
                return lhs.role > rhs.role
            }
            return lhs.generation > rhs.generation
        }
    }

    /// 같은 기수의 Admin 이력을 하나로 병합합니다.
    func mergeAdminLogs(_ logs: [ActivityLog]) -> [ActivityLog] {
        var adminByGen: [Int: [ManagementTeam]] = [:]
        var result: [ActivityLog] = []

        for log in logs {
            if log.part == .admin {
                adminByGen[log.generation, default: []].append(log.role)
            } else {
                result.append(log)
            }
        }

        for (gen, adminRoles) in adminByGen {
            let sortedRoles = adminRoles.sorted(by: >)
            result.append(ActivityLog(
                part: .admin,
                generation: gen,
                roles: sortedRoles
            ))
        }

        return result
    }

    /// 서버 응답의 외부 링크 필드를 `SocialLinkType` 기반 `[ProfileLink]` 배열로 변환합니다.
    func profileLinks() -> [ProfileLink] {
        let mappedLinks: [SocialLinkType: String] = [
            .github: profile?.github?.nonEmpty ?? "",
            .linkedin: profile?.linkedIn?.nonEmpty ?? "",
            .blog: profile?.blog?.nonEmpty ?? ""
        ]

        return SocialLinkType.allCases.map {
            ProfileLink(type: $0, url: mappedLinks[$0] ?? "")
        }
    }

    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 이름을 반환합니다.
    func latestRecordName() -> String {
        let sortedRecords = (challengerRecords ?? [])
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.name ?? name
    }

    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 닉네임을 반환합니다.
    func latestRecordNickname() -> String {
        let sortedRecords = (challengerRecords ?? [])
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.nickname ?? nickname
    }
}

// MARK: - Private String Helpers

private extension String {
    var intValue: Int { Int(self) ?? 0 }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
