//
//  MemberProfileResponseDTOTests.swift
//  CoreNetworkTests
//
//  Auth/MyPage 각자가 소유했던 구 프로필 응답 DTO 테스트의 대표 케이스를
//  정본 DTO 필드명에 맞춰 포팅한다.
//

import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

@Suite("MemberProfileResponseDTO — 내 프로필 조회 응답 디코딩/도메인 매핑")
struct MemberProfileResponseDTOTests {

    // MARK: - Fixtures

    private static func role(
        id: Any = 1,
        challengerId: Any = 100,
        roleType: String = "SCHOOL_PART_LEADER",
        organizationType: String = "SCHOOL",
        organizationId: Any? = 900,
        responsiblePart: String? = "IOS",
        gisu: Any = 11,
        gisuId: Any = 77
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "challengerId": challengerId,
            "roleType": roleType,
            "organizationType": organizationType,
            "gisu": gisu,
            "gisuId": gisuId,
        ]
        dict["organizationId"] = organizationId ?? NSNull()
        if let responsiblePart { dict["responsiblePart"] = responsiblePart }
        return dict
    }

    private static func record(
        challengerId: Any = 111,
        memberId: Any? = 42,
        gisu: Any = 10,
        gisuId: Any = 210,
        chapterId: Any? = 300,
        chapterName: String? = "서울",
        part: String = "IOS",
        schoolId: Any = 900,
        schoolName: String = "한국대학교",
        name: String? = "김철수",
        nickname: String? = "철수",
        email: Any? = "chulsoo@umc.dev",
        profileImageLink: String? = "https://cdn.umc.dev/profile.png",
        status: String? = "ACTIVE",
        memberStatus: String? = nil,
        challengerPoints: [[String: Any]]? = [],
        points: [[String: Any]]? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "challengerId": challengerId,
            "gisu": gisu,
            "gisuId": gisuId,
            "part": part,
            "schoolId": schoolId,
            "schoolName": schoolName,
        ]
        dict["memberId"] = memberId ?? NSNull()
        dict["chapterId"] = chapterId ?? NSNull()
        if let chapterName { dict["chapterName"] = chapterName }
        if let name { dict["name"] = name }
        if let nickname { dict["nickname"] = nickname }
        dict["email"] = email ?? NSNull()
        if let profileImageLink { dict["profileImageLink"] = profileImageLink }
        if let status { dict["status"] = status }
        if let memberStatus { dict["memberStatus"] = memberStatus }
        if let challengerPoints { dict["challengerPoints"] = challengerPoints }
        if let points { dict["points"] = points }
        return dict
    }

    private static func point(
        id: Any = 1,
        pointType: String = "BEST_WORKBOOK",
        point: Any = 3,
        description: String = "우수 워크북",
        createdAt: String = "2026-01-01T00:00:00"
    ) -> [String: Any] {
        [
            "id": id,
            "pointType": pointType,
            "point": point,
            "description": description,
            "createdAt": createdAt,
        ]
    }

    private static func dto(
        id: Any = 42,
        name: String? = "김철수",
        nickname: String? = "철수",
        email: String? = "chulsoo@umc.dev",
        schoolId: Any = 900,
        schoolName: String? = "한국대학교",
        profileImageLink: String? = "https://cdn.umc.dev/profile.png",
        profile: [String: Any]? = [
            "id": 5,
            "linkedIn": "https://linkedin.com/in/chulsoo",
            "instagram": "https://instagram.com/chulsoo",
            "github": "https://github.com/chulsoo",
            "blog": "https://blog.chulsoo.dev",
            "personal": "https://chulsoo.dev",
        ],
        status: String? = "ACTIVE",
        roles: [[String: Any]]? = [],
        challengerRecords: [[String: Any]]? = []
    ) throws -> MemberProfileResponseDTO {
        var dict: [String: Any] = ["id": id, "schoolId": schoolId]
        if let name { dict["name"] = name }
        if let nickname { dict["nickname"] = nickname }
        if let email { dict["email"] = email }
        if let schoolName { dict["schoolName"] = schoolName }
        if let profileImageLink { dict["profileImageLink"] = profileImageLink }
        if let profile { dict["profile"] = profile }
        if let status { dict["status"] = status }
        if let roles { dict["roles"] = roles }
        if let challengerRecords { dict["challengerRecords"] = challengerRecords }

        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(MemberProfileResponseDTO.self, from: data)
    }

    // MARK: - 정상 응답 디코드 → Profile 필드 전체 단언

    @Test("모든 필드가 채워진 정상 응답을 디코딩해 Profile 전체 필드를 단언한다")
    func decodesFullResponseAndMapsAllProfileFields() throws {
        let dto = try Self.dto(
            roles: [Self.role()],
            challengerRecords: [
                Self.record(
                    challengerId: 111, gisu: 10, gisuId: 210,
                    chapterId: 300, chapterName: "서울", part: "IOS",
                    challengerPoints: [Self.point()]
                ),
                Self.record(
                    challengerId: 222, gisu: 11, gisuId: 211,
                    chapterId: 301, chapterName: "부산", part: "ANDROID",
                    challengerPoints: []
                ),
            ]
        )

        #expect(dto.id == "42")
        #expect(dto.email == "chulsoo@umc.dev")
        #expect(dto.schoolId == "900")
        #expect(dto.status == .active)
        #expect(dto.profile?.id == "5")
        #expect(dto.profile?.github == "https://github.com/chulsoo")

        let profile = dto.toDomain()

        #expect(profile.memberId == "42")
        #expect(profile.name == "김철수")
        #expect(profile.nickname == "철수")
        #expect(profile.generations == ["10", "11"])
        #expect(profile.schoolId == "900")
        #expect(profile.schoolName == "한국대학교")
        #expect(profile.latestChallengerId == "222")
        #expect(profile.latestGisuId == "211")
        #expect(profile.chapterId == "301")
        #expect(profile.chapterName == "부산")
        #expect(profile.responsiblePart == "ANDROID")
        #expect(profile.email == "chulsoo@umc.dev")
        #expect(profile.profileImageLink == "https://cdn.umc.dev/profile.png")
        #expect(profile.status == .active)

        let role = try #require(profile.roles.first)
        #expect(role.id == "1")
        #expect(role.challengerId == "100")
        #expect(role.roleType == .schoolPartLeader)
        #expect(role.organizationType == .school)
        #expect(role.organizationId == "900")
        #expect(role.responsiblePart == "IOS")
        #expect(role.gisu == "11")
        #expect(role.gisuId == "77")

        #expect(profile.challengerRecords.count == 2)
        let firstRecord = try #require(profile.challengerRecords.first)
        #expect(firstRecord.challengerId == "111")
        #expect(firstRecord.memberId == "42")
        #expect(firstRecord.challengerPoints.count == 1)
        #expect(firstRecord.challengerPoints.first?.point == 3)

        let externalLinks = try #require(profile.externalLinks)
        #expect(externalLinks.id == "5")
        #expect(externalLinks.linkedIn == "https://linkedin.com/in/chulsoo")
        #expect(externalLinks.instagram == "https://instagram.com/chulsoo")
        #expect(externalLinks.blog == "https://blog.chulsoo.dev")
        #expect(externalLinks.personal == "https://chulsoo.dev")
    }

    // MARK: - roles/challengerRecords 누락 시 [] 폴백

    @Test("roles/challengerRecords 키가 응답에 없으면 빈 배열로 폴백한다")
    func fallsBackToEmptyArraysWhenRolesAndRecordsMissing() throws {
        let dto = try Self.dto(roles: nil, challengerRecords: nil)

        #expect(dto.roles.isEmpty)
        #expect(dto.challengerRecords.isEmpty)

        let profile = dto.toDomain()
        #expect(profile.roles.isEmpty)
        #expect(profile.challengerRecords.isEmpty)
        #expect(profile.generations.isEmpty)
        #expect(profile.generationOrganizations.isEmpty)
    }

    // MARK: - status/memberStatus 폴백

    @Test("status 키가 없고 memberStatus만 있으면 memberStatus로 폴백 디코드한다")
    func fallsBackToMemberStatusKeyWhenStatusMissing() throws {
        let json = try JSONSerialization.data(withJSONObject: Self.record(
            status: nil,
            memberStatus: "INACTIVE"
        ))
        let record = try JSONDecoder().decode(MemberProfileChallengerRecordDTO.self, from: json)

        #expect(record.status == .inactive)
    }

    @Test("status/memberStatus 둘 다 없으면 active로 폴백한다")
    func fallsBackToActiveWhenBothStatusKeysMissing() throws {
        let json = try JSONSerialization.data(withJSONObject: Self.record(status: nil))
        let record = try JSONDecoder().decode(MemberProfileChallengerRecordDTO.self, from: json)

        #expect(record.status == .active)
    }

    // MARK: - challengerPoints/points 폴백

    @Test("challengerPoints 키가 없고 points만 있으면 points로 폴백 디코드한다")
    func fallsBackToPointsKeyWhenChallengerPointsMissing() throws {
        let json = try JSONSerialization.data(withJSONObject: Self.record(
            challengerPoints: nil,
            points: [Self.point(id: 9, pointType: "PENALTY", point: -1, description: "지각")]
        ))
        let record = try JSONDecoder().decode(MemberProfileChallengerRecordDTO.self, from: json)

        #expect(record.challengerPoints.count == 1)
        #expect(record.challengerPoints.first?.id == "9")
        #expect(record.challengerPoints.first?.point == -1)
    }

    @Test("challengerPoints/points 둘 다 없으면 빈 배열로 폴백한다")
    func fallsBackToEmptyArrayWhenBothPointsKeysMissing() throws {
        let json = try JSONSerialization.data(withJSONObject: Self.record(challengerPoints: nil))
        let record = try JSONDecoder().decode(MemberProfileChallengerRecordDTO.self, from: json)

        #expect(record.challengerPoints.isEmpty)
    }

    // MARK: - 옵셔널 필드 null 처리

    @Test("organizationId/chapterId/email 등 옵셔널 필드의 명시적 null을 nil로 디코딩한다")
    func decodesExplicitNullOptionalFieldsAsNil() throws {
        let roleJSON = try JSONSerialization.data(
            withJSONObject: Self.role(organizationId: nil, responsiblePart: nil)
        )
        let role = try JSONDecoder().decode(MemberProfileRoleDTO.self, from: roleJSON)
        #expect(role.organizationId == nil)
        #expect(role.responsiblePart == nil)

        let recordJSON = try JSONSerialization.data(
            withJSONObject: Self.record(memberId: nil, chapterId: nil, email: nil)
        )
        let record = try JSONDecoder().decode(
            MemberProfileChallengerRecordDTO.self,
            from: recordJSON
        )
        #expect(record.memberId == nil)
        #expect(record.chapterId == nil)
        #expect(record.email == nil)
    }

    // MARK: - toDomain() 파생 로직 (Auth 구 프로필 응답 DTO 테스트 포팅)

    @Test("기수 번호를 사전식이 아닌 숫자 크기로 정렬한다 (\"9\"/\"10\" 자릿수 역전 회귀 테스트)")
    func sortsGenerationsNumerically() throws {
        let dto = try Self.dto(
            roles: [Self.role(gisu: "10")],
            challengerRecords: [Self.record(gisu: "9")]
        )

        let profile = dto.toDomain()
        #expect(profile.generations == ["9", "10"])
    }

    @Test("역할/챌린저 기록의 기수 번호 합집합에서 빈 값과 \"0\"을 제외해 정렬한다")
    func mergesGenerationsExcludingZeroAndEmpty() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(gisu: "0"),
                Self.role(gisu: "10"),
            ],
            challengerRecords: [
                Self.record(gisu: "11"),
                Self.record(gisu: ""),
            ]
        )

        let profile = dto.toDomain()
        #expect(profile.generations == ["10", "11"])
    }

    @Test("roleType/organizationType 키가 없으면 각각 challenger/central로 폴백한다")
    func fallsBackToDefaultRoleAndOrganizationTypeWhenKeysAreMissing() throws {
        let json = try JSONSerialization.data(withJSONObject: [
            "gisu": "11",
            "organizationId": NSNull(),
        ])
        let role = try JSONDecoder().decode(MemberProfileRoleDTO.self, from: json)

        #expect(role.roleType == .challenger)
        #expect(role.organizationType == .central)
    }

    @Test("roles와 challengerRecords의 조직 정보를 기수별로 병합해 generationOrganizations를 구성한다")
    func buildsGenerationOrganizationsMergingRolesAndRecords() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(
                    organizationType: "SCHOOL", organizationId: "900",
                    gisu: "11", gisuId: "1"
                ),
            ],
            challengerRecords: [
                Self.record(
                    gisu: "11", gisuId: "1",
                    chapterId: "300", chapterName: "서울",
                    schoolId: "0", schoolName: ""
                ),
            ]
        )

        let profile = dto.toDomain()
        let generationOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "11" }
        )
        #expect(generationOrganization.chapterId == "300")
        #expect(generationOrganization.chapterName == "서울")
        // challengerRecords의 schoolId가 "0"이라 무효 처리되고, roles의 organizationId(900)로 보강된다.
        #expect(generationOrganization.schoolId == "900")
    }

    @Test("challengerRecords가 없는 기수도 roles의 조직 정보만으로 generationOrganizations 항목을 만든다")
    func buildsGenerationOrganizationsFromRolesOnlyGeneration() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(
                    roleType: "CHAPTER_PRESIDENT", organizationType: "CHAPTER",
                    organizationId: "310", gisu: "12", gisuId: "1"
                ),
                Self.role(
                    roleType: "CHALLENGER", organizationType: "CHAPTER",
                    organizationId: "999", gisu: "0", gisuId: "2"
                ),
            ],
            challengerRecords: [
                Self.record(
                    gisu: "11", gisuId: "1",
                    chapterId: "300", chapterName: "서울",
                    schoolId: "900", schoolName: "한국대학교"
                ),
            ]
        )

        let profile = dto.toDomain()

        // 기수 "0" 역할은 제외되고, 숫자 크기 순으로 정렬된다.
        #expect(profile.generationOrganizations.map(\.gen) == ["11", "12"])

        let rolesOnlyOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "12" }
        )
        #expect(rolesOnlyOrganization.chapterId == "310")
        #expect(rolesOnlyOrganization.chapterName == nil)
        #expect(rolesOnlyOrganization.schoolId == nil)
        #expect(rolesOnlyOrganization.schoolName == nil)
    }

    @Test("challengerRecords의 chapterId 누락을 같은 기수 chapter 역할의 organizationId로 backfill한다")
    func backfillsMissingChapterIdFromChapterRole() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(
                    organizationType: "CHAPTER", organizationId: "305",
                    gisu: "11", gisuId: "1"
                ),
            ],
            challengerRecords: [
                Self.record(
                    gisu: "11", gisuId: "1",
                    chapterId: nil, chapterName: nil,
                    schoolId: "900", schoolName: "한국대학교"
                ),
            ]
        )

        let profile = dto.toDomain()
        let generationOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "11" }
        )
        #expect(generationOrganization.chapterId == "305")
        // chapter 역할 backfill은 record의 학교 정보를 덮어쓰지 않고 보존한다.
        #expect(generationOrganization.schoolId == "900")
        #expect(generationOrganization.schoolName == "한국대학교")
    }

    // MARK: - toMemberProfileSummary() (MyPage MyPageProfileResponseDTOTests 포팅)

    @Test("roleType level이 높은 역할이 우선 선정된다 (SCHOOL_PRESIDENT > CHALLENGER)")
    func summaryUsesHighestRoleByLevel() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(roleType: "CHALLENGER", gisu: "11", gisuId: "11"),
                Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "10", gisuId: "10"),
            ]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.roleName == "교내 회장")
        #expect(summary.generation == 10)
    }

    @Test("같은 level이면 generation 내림차순으로 선정된다")
    func summaryBreaksTieByGenerationDescending() throws {
        let dto = try Self.dto(
            roles: [
                Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "10", gisuId: "10"),
                Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "12", gisuId: "12"),
            ]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.generation == 12)
    }

    @Test("roles가 비어 있으면 latestRecord의 기수로 generation을 채운다")
    func summaryFallsBackToLatestRecordGeneration() throws {
        let dto = try Self.dto(
            roles: [],
            challengerRecords: [Self.record(gisu: "7", chapterName: "강남지부")]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.generation == 7)
        #expect(summary.organizationName == "강남지부")
    }

    // MARK: - toMemberProfileSummary() 이름 폴백 (latestRecordName/latestRecordNickname)

    @Test("challengerRecords가 비어 있으면 최상위 name/nickname으로 폴백한다")
    func summaryFallsBackToTopLevelNameWhenRecordsEmpty() throws {
        let dto = try Self.dto(
            name: "탑네임",
            nickname: "탑닉",
            roles: [],
            challengerRecords: []
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.name == "탑네임")
        #expect(summary.nickname == "탑닉")
    }

    @Test("최신 challengerRecord에 name/nickname이 있으면 최상위 값보다 우선한다")
    func summaryPrefersLatestRecordNameOverTopLevel() throws {
        let dto = try Self.dto(
            name: "탑네임",
            nickname: "탑닉",
            roles: [],
            challengerRecords: [
                Self.record(gisu: "5", name: "레코드네임", nickname: "레코드닉"),
            ]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.name == "레코드네임")
        #expect(summary.nickname == "레코드닉")
    }

    @Test("여러 challengerRecords 중 기수가 가장 높은 레코드의 이름/닉네임을 사용한다")
    func summaryUsesHighestGenerationRecordName() throws {
        let dto = try Self.dto(
            name: "탑네임",
            nickname: "탑닉",
            roles: [],
            challengerRecords: [
                Self.record(gisu: "5", name: "구버전", nickname: "구버전닉"),
                Self.record(gisu: "9", name: "신버전", nickname: "신버전닉"),
            ]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.name == "신버전")
        #expect(summary.nickname == "신버전닉")
    }

    @Test("최신 레코드의 name/nickname이 명시적으로 없으면 최상위 값으로 폴백한다")
    func summaryFallsBackToTopLevelNameWhenLatestRecordNameMissing() throws {
        let dto = try Self.dto(
            name: "탑네임",
            nickname: "탑닉",
            roles: [],
            challengerRecords: [
                Self.record(gisu: "5", name: nil, nickname: nil),
            ]
        )

        let summary = dto.toMemberProfileSummary()
        #expect(summary.name == "탑네임")
        #expect(summary.nickname == "탑닉")
    }
}
