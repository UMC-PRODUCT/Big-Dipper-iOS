import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import AuthDomain

// MARK: - Helpers

private func makeIsolatedUserDefaults() -> UserDefaults {
    let suiteName = "SyncProfileStorageUseCaseTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

// MARK: - Tests

@Suite("SyncProfileStorageUseCase — 프로필 로컬 저장소 동기화")
struct SyncProfileStorageUseCaseTests {

    @Test("프로필 정보를 AppStorageKey 전 항목에 정확히 저장한다")
    func savesAllStorageKeysExactly() {
        let userDefaults = makeIsolatedUserDefaults()
        let userSessionManager = UserSessionManager()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: userSessionManager,
            userDefaults: userDefaults
        )
        let generationOrganizations = [
            ProfileGenerationOrganization(
                gen: "11",
                chapterId: "300",
                chapterName: "서울",
                schoolId: "900",
                schoolName: "한국대학교"
            ),
        ]
        let profile = Profile(
            memberId: "42",
            name: "김철수",
            nickname: "철수",
            generations: ["10", "11"],
            schoolId: "900",
            schoolName: "한국대학교",
            latestChallengerId: "555",
            latestGisuId: "77",
            chapterId: "300",
            chapterName: "서울",
            responsiblePart: "IOS",
            roles: [
                ProfileRole(
                    gisu: "11",
                    roleType: .schoolPartLeader,
                    organizationType: .school,
                    organizationId: "700"
                ),
            ],
            generationOrganizations: generationOrganizations
        )

        useCase.execute(profile: profile)

        #expect(userDefaults.string(forKey: AppStorageKey.memberId) == "42")
        #expect(userDefaults.string(forKey: AppStorageKey.schoolId) == "900")
        #expect(userDefaults.string(forKey: AppStorageKey.schoolName) == "한국대학교")
        #expect(userDefaults.string(forKey: AppStorageKey.gisuId) == "77")
        #expect(userDefaults.string(forKey: AppStorageKey.challengerId) == "555")
        #expect(userDefaults.string(forKey: AppStorageKey.chapterId) == "300")
        #expect(userDefaults.string(forKey: AppStorageKey.chapterName) == "서울")
        #expect(userDefaults.string(forKey: AppStorageKey.responsiblePart) == "IOS")
        #expect(userDefaults.string(forKey: AppStorageKey.organizationType) == OrganizationType.school.rawValue)
        #expect(userDefaults.string(forKey: AppStorageKey.organizationId) == "700")
        #expect(userDefaults.string(forKey: AppStorageKey.memberRole) == ManagementTeam.schoolPartLeader.rawValue)
        #expect(
            userDefaults.array(forKey: AppStorageKey.memberRoles) as? [String] ==
                [ManagementTeam.schoolPartLeader.rawValue]
        )
        #expect(userDefaults.bool(forKey: AppStorageKey.canAutoLogin) == true)

        let json = userDefaults.string(forKey: AppStorageKey.generationOrganizations) ?? ""
        let decoded = try? JSONDecoder().decode(
            [ProfileGenerationOrganization].self,
            from: Data(json.utf8)
        )
        #expect(decoded == generationOrganizations)
    }

    @Test("승인되지 않은 프로필(소속 기수 없음)은 canAutoLogin을 false로 저장한다")
    func savesCanAutoLoginFalseWhenNotApproved() {
        let userDefaults = makeIsolatedUserDefaults()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: UserSessionManager(),
            userDefaults: userDefaults
        )
        let profile = Profile(memberId: "1", name: "A", nickname: "a", generations: [])

        useCase.execute(profile: profile)

        #expect(userDefaults.bool(forKey: AppStorageKey.canAutoLogin) == false)
    }

    @Test("역할이 없으면 조직 정보는 chapter/빈 지부ID로, memberRole은 challenger로 폴백한다")
    func fallsBackToDefaultsWhenNoRoles() {
        let userDefaults = makeIsolatedUserDefaults()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: UserSessionManager(),
            userDefaults: userDefaults
        )
        let profile = Profile(
            memberId: "1",
            name: "A",
            nickname: "a",
            generations: ["11"],
            chapterId: "300"
        )

        useCase.execute(profile: profile)

        #expect(userDefaults.string(forKey: AppStorageKey.organizationType) == OrganizationType.chapter.rawValue)
        #expect(userDefaults.string(forKey: AppStorageKey.organizationId) == "300")
        #expect(userDefaults.string(forKey: AppStorageKey.memberRole) == ManagementTeam.challenger.rawValue)
        #expect(userDefaults.array(forKey: AppStorageKey.memberRoles) as? [String] == [])
    }

    @Test(
        "역할은 있지만 organizationId가 nil(중앙 운영진)이면 chapterId로 대체하지 않고 빈 문자열로 저장한다"
    )
    func doesNotFallBackToChapterIdWhenRoleExistsWithNilOrganizationId() {
        let userDefaults = makeIsolatedUserDefaults()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: UserSessionManager(),
            userDefaults: userDefaults
        )
        let profile = Profile(
            memberId: "1",
            name: "A",
            nickname: "a",
            generations: ["11"],
            chapterId: "300",
            roles: [
                ProfileRole(
                    gisu: "11",
                    roleType: .centralPresident,
                    organizationType: .central,
                    organizationId: nil
                ),
            ]
        )

        useCase.execute(profile: profile)

        #expect(userDefaults.string(forKey: AppStorageKey.organizationId) == "")
    }

    @Test("최신 기수 내 동률 role은 우선순위가 더 높은 role을 조직 정보 기준으로 채택한다")
    func picksHighestPriorityRoleWithinLatestGeneration() {
        let userDefaults = makeIsolatedUserDefaults()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: UserSessionManager(),
            userDefaults: userDefaults
        )
        let profile = Profile(
            memberId: "1",
            name: "A",
            nickname: "a",
            generations: ["11"],
            roles: [
                ProfileRole(
                    gisu: "11",
                    roleType: .schoolEtcAdmin,
                    organizationType: .school,
                    organizationId: "100"
                ),
                ProfileRole(
                    gisu: "11",
                    roleType: .schoolPresident,
                    organizationType: .school,
                    organizationId: "200"
                ),
            ]
        )

        useCase.execute(profile: profile)

        #expect(userDefaults.string(forKey: AppStorageKey.organizationId) == "200")
        #expect(userDefaults.string(forKey: AppStorageKey.memberRole) == ManagementTeam.schoolPresident.rawValue)
    }

    @Test(
        "전역 최고 우선순위 role이 최신 기수에 없어도 memberRole은 기수 무관 전역 최고를 반영한다"
    )
    func memberRoleReflectsGlobalHighestPriorityAcrossGenerations() {
        let userDefaults = makeIsolatedUserDefaults()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: UserSessionManager(),
            userDefaults: userDefaults
        )
        let profile = Profile(
            memberId: "1",
            name: "A",
            nickname: "a",
            generations: ["10", "11"],
            roles: [
                // 이전 기수(10)에 더 높은 권한(지부장)을 보유하고 있다.
                ProfileRole(
                    gisu: "10",
                    roleType: .chapterPresident,
                    organizationType: .chapter,
                    organizationId: "500"
                ),
                // 최신 기수(11)에는 더 낮은 권한만 있다.
                ProfileRole(
                    gisu: "11",
                    roleType: .schoolPartLeader,
                    organizationType: .school,
                    organizationId: "700"
                ),
            ]
        )

        useCase.execute(profile: profile)

        // memberRole은 기수와 무관하게 전역 최고 우선순위(chapterPresident)를 따른다.
        #expect(userDefaults.string(forKey: AppStorageKey.memberRole) == ManagementTeam.chapterPresident.rawValue)
        // organizationType/organizationId는 최신 기수(11)의 role을 그대로 따른다.
        #expect(userDefaults.string(forKey: AppStorageKey.organizationType) == OrganizationType.school.rawValue)
        #expect(userDefaults.string(forKey: AppStorageKey.organizationId) == "700")
        #expect(
            Set(userDefaults.array(forKey: AppStorageKey.memberRoles) as? [String] ?? []) ==
                Set([ManagementTeam.chapterPresident.rawValue, ManagementTeam.schoolPartLeader.rawValue])
        )
    }

    @Test("실제 UserSessionManager의 currentRole과 allRoles를 해석된 역할로 갱신한다")
    func updatesUserSessionManagerCurrentRoleAndAllRoles() {
        let userSessionManager = UserSessionManager()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: userSessionManager,
            userDefaults: makeIsolatedUserDefaults()
        )
        let profile = Profile(
            memberId: "1",
            name: "A",
            nickname: "a",
            generations: ["10", "11"],
            roles: [
                ProfileRole(
                    gisu: "11",
                    roleType: .chapterPresident,
                    organizationType: .chapter,
                    organizationId: "500"
                ),
                ProfileRole(
                    gisu: "10",
                    roleType: .schoolPartLeader,
                    organizationType: .school,
                    organizationId: "700"
                ),
            ]
        )

        #expect(userSessionManager.currentRole == .challenger)
        #expect(userSessionManager.allRoles.isEmpty)

        useCase.execute(profile: profile)

        #expect(userSessionManager.currentRole == .chapterPresident)
        #expect(userSessionManager.allRoles == [.chapterPresident, .schoolPartLeader])
    }

    @Test("역할이 없는 프로필은 UserSessionManager의 allRoles를 challenger 하나로 채운다")
    func fillsAllRolesWithChallengerWhenProfileHasNoRoles() {
        let userSessionManager = UserSessionManager()
        let useCase = SyncProfileStorageUseCase(
            userSessionManager: userSessionManager,
            userDefaults: makeIsolatedUserDefaults()
        )
        let profile = Profile(memberId: "1", name: "A", nickname: "a", generations: ["11"])

        useCase.execute(profile: profile)

        #expect(userSessionManager.currentRole == .challenger)
        #expect(userSessionManager.allRoles == [.challenger])
    }
}
