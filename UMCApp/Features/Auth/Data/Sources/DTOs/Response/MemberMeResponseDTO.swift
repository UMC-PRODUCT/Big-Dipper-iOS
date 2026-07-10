import AuthDomain
import CoreDomain
import Foundation
import UMCFoundation

/// 내 프로필 조회 Response DTO
///
/// `GET /api/v1/member/me`
///
/// 부트스트랩 승인 판정 + 로컬 저장소 동기화(`SyncProfileStorageUseCase`)에 필요한 필드를
/// 디코딩한다. 서버 정수 필드(멤버/학교/지부 ID, 기수 번호)는 절대규칙 #2에 따라 `String`으로
/// 통일한다.
public struct MemberMeResponseDTO: Codable {

    // MARK: - Property

    public let id: String
    public let name: String
    public let nickname: String
    public let schoolId: String
    public let schoolName: String
    public let roles: [MemberRoleDTO]
    public let challengerRecords: [MemberChallengerRecordDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nickname
        case schoolId
        case schoolName
        case roles
        case challengerRecords
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        roles = try container.decodeIfPresent([MemberRoleDTO].self, forKey: .roles) ?? []
        challengerRecords = try container.decodeIfPresent(
            [MemberChallengerRecordDTO].self,
            forKey: .challengerRecords
        ) ?? []
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encode(roles, forKey: .roles)
        try container.encode(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - MemberRoleDTO

/// 기수별 역할 정보 DTO.
public struct MemberRoleDTO: Codable {

    // MARK: - Property

    public let gisu: String
    public let roleType: ManagementTeam
    public let organizationType: OrganizationType
    public let organizationId: String?

    private enum CodingKeys: String, CodingKey {
        case gisu
        case roleType
        case organizationType
        case organizationId
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
        roleType = try container.decodeIfPresent(ManagementTeam.self, forKey: .roleType)
            ?? .challenger
        // 레거시 `AppProduct/.../Home/Data/DTO/MyProfileDTO.swift`의 `RoleDTO.init(from:)`도
        // 동일하게 `.central`로 폴백한다(중앙 운영진은 지부/학교 무소속이 기본값이라는 서버 계약과 일치).
        organizationType = try container.decodeIfPresent(
            OrganizationType.self,
            forKey: .organizationType
        ) ?? .central
        organizationId = container.decodeFlexibleStringOrNil(forKey: .organizationId)
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(roleType, forKey: .roleType)
        try container.encode(organizationType, forKey: .organizationType)
        try container.encodeIfPresent(organizationId, forKey: .organizationId)
    }
}

// MARK: - MemberChallengerRecordDTO

/// 챌린저 이력 정보 DTO.
public struct MemberChallengerRecordDTO: Codable {

    // MARK: - Property

    public let gisu: String
    public let challengerId: String
    public let gisuId: String
    public let chapterId: String?
    public let chapterName: String?
    public let part: String
    public let schoolId: String
    public let schoolName: String

    private enum CodingKeys: String, CodingKey {
        case gisu
        case challengerId
        case gisuId
        case chapterId
        case chapterName
        case part
        case schoolId
        case schoolName
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
        challengerId = container.decodeFlexibleStringOrEmpty(forKey: .challengerId)
        gisuId = container.decodeFlexibleStringOrEmpty(forKey: .gisuId)
        chapterId = container.decodeFlexibleStringOrNil(forKey: .chapterId)
        chapterName = try container.decodeIfPresent(String.self, forKey: .chapterName)
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encodeIfPresent(chapterId, forKey: .chapterId)
        try container.encodeIfPresent(chapterName, forKey: .chapterName)
        try container.encode(part, forKey: .part)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
    }
}

// MARK: - toDomain

extension MemberMeResponseDTO {
    /// DTO → `Profile` 도메인 모델 변환.
    ///
    /// 역할(roles)과 챌린저 이력(challengerRecords) 양쪽에서 기수 번호를 모아 합집합을 구성하고,
    /// 챌린저 이력 중 숫자 기수가 가장 큰 레코드를 최신 기록으로 채택한다
    /// (레거시 `MyProfileResponseDTO.toHomeProfileResult()` 대응).
    func toDomain() -> AuthDomain.Profile {
        let generations = Set(roles.map(\.gisu) + challengerRecords.map(\.gisu))
            .filter { !$0.isEmpty && $0 != "0" }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }

        let latestRecord = challengerRecords.max {
            (Int($0.gisu) ?? 0) < (Int($1.gisu) ?? 0)
        }

        let profileRoles = roles.map {
            AuthDomain.ProfileRole(
                gisu: $0.gisu,
                roleType: $0.roleType,
                organizationType: $0.organizationType,
                organizationId: $0.organizationId
            )
        }

        return AuthDomain.Profile(
            memberId: id,
            name: name,
            nickname: nickname,
            generations: Array(generations),
            schoolId: schoolId,
            schoolName: schoolName,
            latestChallengerId: latestRecord?.challengerId,
            latestGisuId: latestRecord?.gisuId,
            chapterId: latestRecord?.chapterId,
            chapterName: latestRecord?.chapterName ?? "",
            responsiblePart: latestRecord?.part,
            roles: profileRoles,
            generationOrganizations: Self.buildGenerationOrganizations(
                records: challengerRecords,
                roles: roles
            )
        )
    }

    /// 챌린저 이력(학교/지부)을 우선 채택하고, 역할(roles)의 조직 정보로 누락된 값을 보강한다.
    private static func buildGenerationOrganizations(
        records: [MemberChallengerRecordDTO],
        roles: [MemberRoleDTO]
    ) -> [ProfileGenerationOrganization] {
        var byGeneration: [String: ProfileGenerationOrganization] = [:]

        for record in records where (Int(record.gisu) ?? 0) > 0 {
            byGeneration[record.gisu] = ProfileGenerationOrganization(
                gen: record.gisu,
                chapterId: record.chapterId,
                chapterName: record.chapterName,
                schoolId: (Int(record.schoolId) ?? 0) > 0 ? record.schoolId : nil,
                schoolName: record.schoolName.isEmpty ? nil : record.schoolName
            )
        }

        for role in roles where (Int(role.gisu) ?? 0) > 0 {
            let existing = byGeneration[role.gisu]
            let chapterId = role.organizationType == .chapter
                ? role.organizationId
                : existing?.chapterId
            let schoolId = role.organizationType == .school
                ? role.organizationId
                : existing?.schoolId
            byGeneration[role.gisu] = ProfileGenerationOrganization(
                gen: role.gisu,
                chapterId: chapterId,
                chapterName: existing?.chapterName,
                schoolId: schoolId,
                schoolName: existing?.schoolName
            )
        }

        return byGeneration.values.sorted { (Int($0.gen) ?? 0) < (Int($1.gen) ?? 0) }
    }
}
