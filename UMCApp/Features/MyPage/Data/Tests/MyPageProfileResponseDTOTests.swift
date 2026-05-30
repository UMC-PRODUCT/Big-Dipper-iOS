//
//  MyPageProfileResponseDTOTests.swift
//  MyPageDataTests
//
//  toProfileData() / toMemberProfileSummary() 도메인 변환 로직 검증.
//

import Foundation
import Testing
import CoreEnum
import CoreDomain
import MyPageDomain
@testable import MyPageData

@Suite("MyPageProfileResponseDTO — 도메인 변환 (toProfileData / toMemberProfileSummary)")
struct MyPageProfileResponseDTOTests {

    // MARK: - Fixtures

    private static func record(
        challengerId: String = "100",
        memberId: String = "1",
        gisu: String,
        part: String,
        name: String = "이름",
        nickname: String = "닉",
        schoolName: String = "학교",
        chapterName: String? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "challengerId": challengerId,
            "memberId": memberId,
            "gisu": gisu,
            "part": part,
            "challengerPoints": [],
            "name": name,
            "nickname": nickname,
            "schoolId": "1",
            "schoolName": schoolName,
            "status": "ACTIVE"
        ]
        if let chapterName { dict["chapterName"] = chapterName }
        return dict
    }

    private static func role(
        roleType: String,
        gisu: String? = nil,
        gisuId: String = "1",
        responsiblePart: String? = nil,
        organizationType: String = "SCHOOL"
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "id": "1",
            "challengerId": "100",
            "roleType": roleType,
            "organizationType": organizationType,
            "gisuId": gisuId
        ]
        if let gisu { dict["gisu"] = gisu }
        if let responsiblePart { dict["responsiblePart"] = responsiblePart }
        return dict
    }

    private static func dto(
        roles: [[String: Any]] = [],
        records: [[String: Any]]? = nil,
        profile: [String: String]? = nil
    ) throws -> MyPageProfileResponseDTO {
        var dict: [String: Any] = [
            "id": "1",
            "name": "전체이름",
            "nickname": "전체닉",
            "email": "test@umc.kr",
            "schoolId": "1",
            "schoolName": "전체학교",
            "status": "ACTIVE",
            "roles": roles
        ]
        if let records {
            dict["challengerRecords"] = records
        }
        if let profile {
            var profileDict: [String: Any] = ["id": "1"]
            profile.forEach { profileDict[$0.key] = $0.value }
            dict["profile"] = profileDict
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(MyPageProfileResponseDTO.self, from: data)
    }

    // MARK: - toProfileData

    @Test("빈 입력 → 기본값 (challengeId=0, gen=0, 빈 activityLogs)")
    func emptyInputGivesDefaults() throws {
        let dto = try Self.dto()
        let profile = dto.toProfileData()

        #expect(profile.challengeId == "0")
        #expect(profile.challengerInfo.gen == 0)
        #expect(profile.activityLogs.isEmpty)
        #expect(profile.profileLink.count == SocialLinkType.allCases.count)
    }

    @Test("가장 높은 기수 챌린저 기록의 정보로 ChallengerInfo가 채워진다")
    func latestRecordPopulatesChallengerInfo() throws {
        let records = [
            Self.record(gisu: "5",  part: "IOS", name: "구버전", nickname: "old"),
            Self.record(gisu: "11", part: "IOS", name: "신버전", nickname: "new")
        ]
        let dto = try Self.dto(records: records)
        let profile = dto.toProfileData()

        #expect(profile.challengerInfo.gen == 11)
        #expect(profile.challengerInfo.name == "신버전")
        #expect(profile.challengerInfo.nickname == "new")
    }

    @Test("ADMIN part 챌린저 기록은 visibleRecords에서 제외되어 latestRecord 선정 후보가 아니다")
    func adminPartRecordsExcludedFromVisible() throws {
        let records = [
            Self.record(gisu: "12", part: "ADMIN", name: "어드민"),
            Self.record(gisu: "5",  part: "IOS",   name: "iOS")
        ]
        let dto = try Self.dto(records: records)
        let profile = dto.toProfileData()

        #expect(profile.challengerInfo.gen == 5)
        #expect(profile.challengerInfo.name == "iOS")
    }

    @Test("같은 기수의 admin 역할 여러 개는 하나의 ActivityLog로 병합된다")
    func adminRolesMergedBySameGeneration() throws {
        let roles = [
            Self.role(
                roleType: "SCHOOL_PRESIDENT",
                gisu: "11", gisuId: "11",
                responsiblePart: "ADMIN"
            ),
            Self.role(
                roleType: "SCHOOL_PART_LEADER",
                gisu: "11", gisuId: "11",
                responsiblePart: "ADMIN"
            )
        ]
        let dto = try Self.dto(roles: roles)
        let profile = dto.toProfileData()

        let admin11 = profile.activityLogs.first {
            $0.part == .admin && $0.generation == "11"
        }
        #expect(admin11 != nil)
        #expect(admin11?.roles.count == 2)
        #expect(admin11?.roles.contains(.schoolPresident) == true)
        #expect(admin11?.roles.contains(.schoolPartLeader) == true)
    }

    @Test("profile 외부 링크가 SocialLinkType 3종(github/linkedin/blog)으로 매핑된다")
    func profileLinksMappedToSocialLinkTypes() throws {
        let profile: [String: String] = [
            "github": "https://github.com/me",
            "linkedIn": "https://linkedin.com/in/me",
            "blog": "https://blog.me"
        ]
        let dto = try Self.dto(profile: profile)
        let result = dto.toProfileData()

        let github = result.profileLink.first { $0.type == .github }
        let linkedin = result.profileLink.first { $0.type == .linkedin }
        let blog = result.profileLink.first { $0.type == .blog }

        #expect(github?.url == "https://github.com/me")
        #expect(linkedin?.url == "https://linkedin.com/in/me")
        #expect(blog?.url == "https://blog.me")
    }

    // MARK: - toMemberProfileSummary

    @Test("roleType level이 높은 역할이 우선 선정된다 (SCHOOL_PRESIDENT > CHALLENGER)")
    func summaryUsesHighestRoleByLevel() throws {
        let roles = [
            Self.role(roleType: "CHALLENGER",       gisu: "11", gisuId: "11"),
            Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "10", gisuId: "10")
        ]
        let dto = try Self.dto(roles: roles)
        let summary = dto.toMemberProfileSummary()

        #expect(summary.roleName == "교내 회장")
        #expect(summary.generation == "10")
    }

    @Test("같은 level이면 generation 내림차순으로 선정된다")
    func summaryBreaksTieByGenerationDescending() throws {
        let roles = [
            Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "10", gisuId: "10"),
            Self.role(roleType: "SCHOOL_PRESIDENT", gisu: "12", gisuId: "12")
        ]
        let dto = try Self.dto(roles: roles)
        let summary = dto.toMemberProfileSummary()

        #expect(summary.generation == "12")
    }

    @Test("roles가 비어 있으면 latestRecord의 기수로 generation을 채운다")
    func summaryFallsBackToLatestRecordGeneration() throws {
        let records = [
            Self.record(gisu: "7", part: "IOS", chapterName: "강남지부")
        ]
        let dto = try Self.dto(records: records)
        let summary = dto.toMemberProfileSummary()

        #expect(summary.generation == "7")
        #expect(summary.organizationName == "강남지부")
    }
}
