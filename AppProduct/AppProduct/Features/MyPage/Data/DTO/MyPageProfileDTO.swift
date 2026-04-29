//
//  MyPageProfileDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/15/26.
//

import Foundation

/// 마이페이지 내 프로필 조회/수정 응답 DTO
struct MyPageProfileResponseDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeMyPageFlexibleString(forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decode(String.self, forKey: .nickname)
        email = try container.decodeMyPageFlexibleStringIfPresent(forKey: .email) ?? ""
        schoolId = try container.decodeMyPageFlexibleString(forKey: .schoolId)
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
}

/// 특정 멤버 프로필 조회 응답에서 작성자 표시용으로 추출할 정보
struct MemberProfileSummary {
    let memberId: String
    let name: String
    let nickname: String
    let generation: Int
    let organizationName: String?
    let roleName: String
    let profileImageURL: String?
}

/// `/api/v1/member/me` 응답의 `profile` 하위 객체
struct MyPageProfileExternalLinksDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeMyPageFlexibleStringIfPresent(forKey: .id) ?? ""
        linkedIn = try container.decodeMyPageFlexibleStringIfPresent(forKey: .linkedIn)
        instagram = try container.decodeMyPageFlexibleStringIfPresent(forKey: .instagram)
        github = try container.decodeMyPageFlexibleStringIfPresent(forKey: .github)
        blog = try container.decodeMyPageFlexibleStringIfPresent(forKey: .blog)
        personal = try container.decodeMyPageFlexibleStringIfPresent(forKey: .personal)
    }
}

struct MyPageRoleDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeMyPageFlexibleString(forKey: .id)
        challengerId = try container.decodeMyPageFlexibleString(forKey: .challengerId)
        roleType = try container.decode(ManagementTeam.self, forKey: .roleType)
        organizationType = try container.decode(OrganizationType.self, forKey: .organizationType)
        organizationId = try container.decodeMyPageFlexibleStringIfPresent(forKey: .organizationId)
        responsiblePart = try container.decodeIfPresent(String.self, forKey: .responsiblePart)
        gisu = try container.decodeMyPageFlexibleStringIfPresent(forKey: .gisu)
        gisuId = try container.decodeMyPageFlexibleString(forKey: .gisuId)
    }
}

struct MyPageChallengerRecordDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeMyPageFlexibleString(forKey: .challengerId)
        memberId = try container.decodeMyPageFlexibleString(forKey: .memberId)
        gisu = try container.decodeMyPageFlexibleString(forKey: .gisu)
        chapterName = try container.decodeIfPresent(String.self, forKey: .chapterName)
        part = try container.decode(String.self, forKey: .part)
        challengerPoints = try container.decodeIfPresent([MyPageChallengerPointDTO].self, forKey: .challengerPoints)
            ?? decoder.decodeMyPagePointsArrayFallback()
            ?? []
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decode(String.self, forKey: .nickname)
        email = try container.decodeMyPageFlexibleStringIfPresent(forKey: .email)
        schoolId = try container.decodeMyPageFlexibleString(forKey: .schoolId)
        schoolName = try container.decode(String.self, forKey: .schoolName)
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)
        let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status)
            ?? fallbackContainer.decodeIfPresent(MemberStatus.self, forKey: .memberStatus)
            ?? .active
    }
}

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
    func decodeMyPagePointsArrayFallback() throws -> [MyPageChallengerPointDTO]? {
        let container = try self.container(keyedBy: MyPageDynamicCodingKey.self)
        guard let key = MyPageDynamicCodingKey(stringValue: "points") else {
            return nil
        }
        return try container.decodeIfPresent([MyPageChallengerPointDTO].self, forKey: key)
    }
}

struct MyPageChallengerPointDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeMyPageFlexibleString(forKey: .id)
        pointType = try container.decode(String.self, forKey: .pointType)
        point = try container.decodeFlexibleDouble(forKey: .point)
        description = try container.decode(String.self, forKey: .description)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

extension MyPageProfileResponseDTO {
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

    private func activityLogs(records: [MyPageChallengerRecordDTO]) -> [ActivityLog] {
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
    private func mergeAdminLogs(_ logs: [ActivityLog]) -> [ActivityLog] {
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
    private func profileLinks() -> [ProfileLink] {
        let mappedLinks: [SocialLinkType: String] = [
            .github: profile?.github?.nonEmpty ?? "",
            .linkedin: profile?.linkedIn?.nonEmpty ?? "",
            .blog: profile?.blog?.nonEmpty ?? ""
        ]

        return SocialLinkType.allCases.map {
            ProfileLink(type: $0, url: mappedLinks[$0] ?? "")
        }
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

    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 이름을 반환합니다.
    private func latestRecordName() -> String {
        let sortedRecords = (challengerRecords ?? [])
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.name ?? name
    }

    /// 기수(generation) 내림차순으로 정렬하여 가장 최신 기수의 닉네임을 반환합니다.
    private func latestRecordNickname() -> String {
        let sortedRecords = (challengerRecords ?? [])
            .sorted { Int($0.gisu) ?? 0 > Int($1.gisu) ?? 0 }
        return sortedRecords.first?.nickname ?? nickname
    }
}

private extension String {
    var intValue: Int { Int(self) ?? 0 }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
