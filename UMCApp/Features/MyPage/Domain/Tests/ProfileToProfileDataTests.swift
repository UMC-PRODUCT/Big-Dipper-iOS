//
//  ProfileToProfileDataTests.swift
//  MyPageDomainTests
//
//  `Profile.toProfileData()` 도메인 변환 로직 검증.
//  (원본 MyPageData `MyPageProfileResponseDTOTests.toProfileData` 스위트 이식 — JSON 디코딩
//  없이 정본 `CoreDomain.Profile`을 직접 구성해 검증한다. `toMemberProfileSummary()` 케이스는
//  `Core/Network/Tests/Member/MemberProfileResponseDTOTests.swift`에서 이미 커버된다.)
//

import Testing
import CoreDomain
import UMCFoundation
@testable import MyPageDomain

@Suite("Profile.toProfileData()")
struct ProfileToProfileDataTests {

    // MARK: - Fixtures

    private static func makeProfile(
        roles: [ProfileRole] = [],
        challengerRecords: [ProfileChallengerRecord] = [],
        externalLinks: ProfileExternalLinks? = nil
    ) -> Profile {
        Profile(
            memberId: "1",
            name: "전체이름",
            nickname: "전체닉",
            generations: [],
            schoolId: "1",
            schoolName: "전체학교",
            roles: roles,
            email: "test@umc.kr",
            status: .active,
            externalLinks: externalLinks,
            challengerRecords: challengerRecords
        )
    }

    private static func record(
        challengerId: String = "100",
        gisu: String,
        part: String,
        name: String = "이름",
        nickname: String = "닉",
        schoolName: String = "학교"
    ) -> ProfileChallengerRecord {
        ProfileChallengerRecord(
            challengerId: challengerId,
            memberId: "1",
            gisu: gisu,
            gisuId: gisu,
            chapterId: nil,
            chapterName: nil,
            part: part,
            schoolId: "1",
            schoolName: schoolName,
            name: name,
            nickname: nickname,
            email: nil,
            profileImageLink: nil,
            status: .active,
            challengerPoints: []
        )
    }

    private static func role(
        roleType: ManagementTeam,
        gisu: String,
        gisuId: String,
        responsiblePart: String? = nil,
        organizationType: OrganizationType = .school
    ) -> ProfileRole {
        ProfileRole(
            id: "1",
            challengerId: "100",
            gisu: gisu,
            gisuId: gisuId,
            roleType: roleType,
            organizationType: organizationType,
            organizationId: nil,
            responsiblePart: responsiblePart
        )
    }

    // MARK: - Tests

    @Test("빈 입력 → 기본값 (challengeId=0, gen=0, 빈 activityLogs)")
    func emptyInputGivesDefaults() {
        let profile = Self.makeProfile()
        let result = profile.toProfileData()

        #expect(result.challengeId == 0)
        #expect(result.challengerInfo.gen == "0")
        #expect(result.activityLogs.isEmpty)
        #expect(result.profileLink.count == SocialLinkType.allCases.count)
    }

    @Test("가장 높은 기수 챌린저 기록의 정보로 ChallengerInfo가 채워진다")
    func latestRecordPopulatesChallengerInfo() {
        let records = [
            Self.record(gisu: "5", part: "IOS", name: "구버전", nickname: "old"),
            Self.record(gisu: "11", part: "IOS", name: "신버전", nickname: "new")
        ]
        let profile = Self.makeProfile(challengerRecords: records)
        let result = profile.toProfileData()

        #expect(result.challengerInfo.gen == "11")
        #expect(result.challengerInfo.name == "신버전")
        #expect(result.challengerInfo.nickname == "new")
    }

    @Test("ADMIN part 챌린저 기록은 visibleRecords에서 제외되어 latestRecord 선정 후보가 아니다")
    func adminPartRecordsExcludedFromVisible() {
        let records = [
            Self.record(gisu: "12", part: "ADMIN", name: "어드민"),
            Self.record(gisu: "5", part: "IOS", name: "iOS")
        ]
        let profile = Self.makeProfile(challengerRecords: records)
        let result = profile.toProfileData()

        #expect(result.challengerInfo.gen == "5")
        #expect(result.challengerInfo.name == "iOS")
    }

    @Test("같은 기수의 admin 역할 여러 개는 하나의 ActivityLog로 병합된다")
    func adminRolesMergedBySameGeneration() {
        let roles = [
            Self.role(roleType: .schoolPresident, gisu: "11", gisuId: "11", responsiblePart: "ADMIN"),
            Self.role(roleType: .schoolPartLeader, gisu: "11", gisuId: "11", responsiblePart: "ADMIN")
        ]
        let profile = Self.makeProfile(roles: roles)
        let result = profile.toProfileData()

        let admin11 = result.activityLogs.first { $0.part == .admin && $0.generation == 11 }
        #expect(admin11 != nil)
        #expect(admin11?.roles.count == 2)
        #expect(admin11?.roles.contains(.schoolPresident) == true)
        #expect(admin11?.roles.contains(.schoolPartLeader) == true)
    }

    @Test("profile 외부 링크가 SocialLinkType 3종(github/linkedin/blog)으로 매핑된다")
    func profileLinksMappedToSocialLinkTypes() {
        let externalLinks = ProfileExternalLinks(
            id: "1",
            linkedIn: "https://linkedin.com/in/me",
            instagram: nil,
            github: "https://github.com/me",
            blog: "https://blog.me",
            personal: nil
        )
        let profile = Self.makeProfile(externalLinks: externalLinks)
        let result = profile.toProfileData()

        let github = result.profileLink.first { $0.type == .github }
        let linkedin = result.profileLink.first { $0.type == .linkedin }
        let blog = result.profileLink.first { $0.type == .blog }

        #expect(github?.url == "https://github.com/me")
        #expect(linkedin?.url == "https://linkedin.com/in/me")
        #expect(blog?.url == "https://blog.me")
    }
}
