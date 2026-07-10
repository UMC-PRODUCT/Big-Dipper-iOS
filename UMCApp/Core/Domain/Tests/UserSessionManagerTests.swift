import Testing
import UMCFoundation
@testable import CoreDomain

@Suite("UserSessionManager — 세션 역할·Admin 모드 상태")
struct UserSessionManagerTests {

    // MARK: - 초기 상태

    @Test("초기 상태는 challenger 역할, 빈 역할 목록, Admin 모드 비활성이다")
    func initialStateIsChallengerWithAdminModeDisabled() {
        let manager = UserSessionManager()

        #expect(manager.currentRole == .challenger)
        #expect(manager.allRoles.isEmpty)
        #expect(manager.isAdminModeEnabled == false)
        #expect(manager.canToggleAdminMode == false)
        #expect(manager.currentActivityMode == .challenger)
    }

    // MARK: - updateRole

    @Test("allRoles 없이 updateRole하면 현재 역할 하나로 역할 목록을 채운다")
    func updateRoleWithoutAllRolesFallsBackToSingleRole() {
        let manager = UserSessionManager()

        manager.updateRole(.schoolPresident)

        #expect(manager.currentRole == .schoolPresident)
        #expect(manager.allRoles == [.schoolPresident])
    }

    @Test("allRoles를 함께 전달하면 역할 목록을 그대로 저장한다")
    func updateRoleStoresProvidedAllRoles() {
        let manager = UserSessionManager()

        manager.updateRole(
            .chapterPresident,
            allRoles: [.chapterPresident, .schoolPartLeader, .challenger]
        )

        #expect(manager.currentRole == .chapterPresident)
        #expect(manager.allRoles == [.chapterPresident, .schoolPartLeader, .challenger])
    }

    @Test("Admin 모드 접근 불가 역할로 변경되면 Admin 모드가 비활성화된다")
    func updateRoleToNonAdminRoleDisablesAdminMode() {
        let manager = UserSessionManager()
        manager.updateRole(.schoolPresident)
        manager.toggleAdminMode()
        #expect(manager.isAdminModeEnabled == true)

        manager.updateRole(.challenger)

        #expect(manager.isAdminModeEnabled == false)
        #expect(manager.currentActivityMode == .challenger)
    }

    @Test("Admin 모드 접근 가능 역할로 변경되면 활성화된 Admin 모드를 유지한다")
    func updateRoleToAdminCapableRoleKeepsAdminModeEnabled() {
        let manager = UserSessionManager()
        manager.updateRole(.schoolPresident)
        manager.toggleAdminMode()

        manager.updateRole(.chapterPresident)

        #expect(manager.isAdminModeEnabled == true)
        #expect(manager.currentActivityMode == .admin)
    }

    // MARK: - toggleAdminMode

    @Test("Admin 모드 접근 불가 역할은 토글해도 Admin 모드가 켜지지 않는다")
    func toggleAdminModeIsIgnoredForNonAdminRole() {
        let manager = UserSessionManager()
        manager.updateRole(.challenger)

        manager.toggleAdminMode()

        #expect(manager.isAdminModeEnabled == false)
    }

    @Test("Admin 모드 접근 가능 역할은 토글로 Admin 모드를 켜고 끌 수 있다")
    func toggleAdminModeSwitchesModeForAdminCapableRole() {
        let manager = UserSessionManager()
        manager.updateRole(.schoolEtcAdmin)

        manager.toggleAdminMode()
        #expect(manager.isAdminModeEnabled == true)
        #expect(manager.currentActivityMode == .admin)

        manager.toggleAdminMode()
        #expect(manager.isAdminModeEnabled == false)
        #expect(manager.currentActivityMode == .challenger)
    }

    // MARK: - hasAnyRole

    @Test("hasAnyRole은 보유 역할 목록 전체에서 조건을 검사한다")
    func hasAnyRoleChecksAllRoles() {
        let manager = UserSessionManager()
        manager.updateRole(
            .schoolPartLeader,
            allRoles: [.schoolPartLeader, .challenger]
        )

        #expect(manager.hasAnyRole(where: { $0 == .challenger }))
        #expect(manager.hasAnyRole(where: \.canAccessAdminMode))
        #expect(manager.hasAnyRole(where: { $0 == .centralPresident }) == false)
    }

    // MARK: - reset

    @Test("reset은 역할·역할 목록·Admin 모드를 초기 상태로 되돌린다")
    func resetRestoresInitialState() {
        let manager = UserSessionManager()
        manager.updateRole(
            .centralPresident,
            allRoles: [.centralPresident, .schoolPresident]
        )
        manager.toggleAdminMode()

        manager.reset()

        #expect(manager.currentRole == .challenger)
        #expect(manager.allRoles.isEmpty)
        #expect(manager.isAdminModeEnabled == false)
        #expect(manager.currentActivityMode == .challenger)
    }
}
