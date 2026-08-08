//
//  ScheduleDetailViewModelTests.swift
//  HomePresentationTests
//
//  Created by euijjang97 on 8/6/26.
//

import CoreDI
import CoreDomain
import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import HomePresentation

@MainActor
@Suite("ScheduleDetailViewModel — 출석 현황 진입 가능 여부")
struct ScheduleDetailViewModelTests {

    @Test("Admin 모드 + 출석 정책 있음 → 출석 현황 진입 가능")
    func adminWithPolicyCanViewAttendanceStatus() async {
        let viewModel = makeViewModel(hasAttendancePolicy: true, isAdminMode: true)

        await viewModel.load()

        #expect(viewModel.canViewAttendanceStatus)
    }

    @Test("Admin 모드 + 출석 정책 없음 → 진입 불가")
    func adminWithoutPolicyCannotViewAttendanceStatus() async {
        let viewModel = makeViewModel(hasAttendancePolicy: false, isAdminMode: true)

        await viewModel.load()

        #expect(viewModel.canViewAttendanceStatus == false)
    }

    @Test("Challenger 모드 + 출석 정책 있음 → 진입 불가")
    func challengerWithPolicyCannotViewAttendanceStatus() async {
        let viewModel = makeViewModel(hasAttendancePolicy: true, isAdminMode: false)

        await viewModel.load()

        #expect(viewModel.canViewAttendanceStatus == false)
    }
}

@MainActor
@Suite("ScheduleDetailViewModel — 권한 판정과 삭제 에스컬레이션")
struct ScheduleDetailPermissionTests {

    @Test("edit/write/manage 는 수정, delete/manage 는 삭제, forceDelete/manage 는 강제 삭제를 연다")
    func permissionsMapToActions() async {
        let viewModel = makeViewModel(permissions: [.edit, .delete])

        await viewModel.fetchSchedulePermission()

        #expect(viewModel.canEditSchedule)
        #expect(viewModel.canDeleteSchedule)
        #expect(viewModel.canForceDeleteSchedule == false)
    }

    @Test("manage 단독으로도 수정·삭제·강제 삭제가 모두 열린다")
    func managePermissionOpensEverything() async {
        let viewModel = makeViewModel(permissions: [.manage])

        await viewModel.fetchSchedulePermission()

        #expect(viewModel.canEditSchedule)
        #expect(viewModel.canDeleteSchedule)
        #expect(viewModel.canForceDeleteSchedule)
    }

    @Test("read 권한만 있으면 어떤 액션도 열리지 않는다")
    func readOnlyPermissionOpensNothing() async {
        let viewModel = makeViewModel(permissions: [.read])

        await viewModel.fetchSchedulePermission()

        #expect(viewModel.canEditSchedule == false)
        #expect(viewModel.canDeleteSchedule == false)
        #expect(viewModel.canForceDeleteSchedule == false)
    }

    @Test("권한 조회가 실패하면 전부 닫는다")
    func permissionFailureClosesEverything() async {
        let viewModel = makeViewModel(permissions: [.manage], permissionFails: true)

        await viewModel.fetchSchedulePermission()

        #expect(viewModel.canEditSchedule == false)
        #expect(viewModel.canDeleteSchedule == false)
        #expect(viewModel.canForceDeleteSchedule == false)
    }

    @Test("출석 기록 때문에 삭제가 거부되고 강제 삭제 권한이 있으면 2차 확인을 띄운다")
    func attendanceRecordsEscalateToForceDelete() async {
        let viewModel = makeViewModel(
            permissions: [.manage],
            deleteError: DomainError.scheduleHasAttendanceRecords
        )
        await viewModel.fetchSchedulePermission()

        await viewModel.deleteSchedule()

        #expect(viewModel.alertPrompt?.title == "출석 기록 포함 일정 강제 삭제")
        #expect(viewModel.isDeleted == false)
    }

    @Test("강제 삭제 권한이 없으면 같은 거부에도 2차 확인을 띄우지 않는다")
    func attendanceRecordsWithoutForceDeleteShowsNoPrompt() async {
        let viewModel = makeViewModel(
            permissions: [.delete],
            deleteError: DomainError.scheduleHasAttendanceRecords
        )
        await viewModel.fetchSchedulePermission()

        await viewModel.deleteSchedule()

        #expect(viewModel.alertPrompt == nil)
        #expect(viewModel.isDeleted == false)
    }

    @Test("삭제에 성공하면 화면을 닫도록 isDeleted 를 세운다")
    func successfulDeleteMarksDeleted() async {
        let viewModel = makeViewModel(permissions: [.delete])
        await viewModel.fetchSchedulePermission()

        await viewModel.deleteSchedule()

        #expect(viewModel.isDeleted)
        #expect(viewModel.alertPrompt == nil)
    }
}

// MARK: - Helpers

@MainActor
private func makeViewModel(
    hasAttendancePolicy: Bool = false,
    isAdminMode: Bool = false,
    permissions: Set<AuthorizationPermissionType> = [],
    permissionFails: Bool = false,
    deleteError: Error? = nil
) -> ScheduleDetailViewModel {
    let container = DIContainer()
    container.register(FetchScheduleDetailUseCaseProtocol.self) {
        StubFetchScheduleDetailUseCase(hasAttendancePolicy: hasAttendancePolicy)
    }
    container.register(AuthorizationUseCaseProtocol.self) {
        StubAuthorizationUseCase(permissions: permissions, shouldFail: permissionFails)
    }
    container.register(DeleteScheduleUseCaseProtocol.self) {
        StubDeleteScheduleUseCase(error: deleteError)
    }
    container.register(ForceDeleteScheduleUseCaseProtocol.self) {
        StubForceDeleteScheduleUseCase()
    }
    container.register(UserSessionManager.self) { makeSession(isAdminMode: isAdminMode) }
    return ScheduleDetailViewModel(
        container: container,
        scheduleId: "1",
        errorHandler: ErrorHandler()
    )
}

/// Admin 모드는 토글 가능 역할일 때만 켜지므로, 역할부터 맞춘 뒤 토글한다.
private func makeSession(isAdminMode: Bool) -> UserSessionManager {
    let session = UserSessionManager()
    guard isAdminMode else { return session }
    session.updateRole(.schoolPresident)
    session.toggleAdminMode()
    return session
}

// MARK: - Stubs

private struct StubFetchScheduleDetailUseCase: FetchScheduleDetailUseCaseProtocol {

    let hasAttendancePolicy: Bool

    func execute(scheduleId: String) async throws -> ScheduleDetailData {
        let startsAt = Date.now
        return ScheduleDetailData(
            scheduleId: scheduleId,
            name: "정기 세미나",
            description: "",
            tags: [],
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(3_600),
            isParticipant: true,
            attendancePolicy: hasAttendancePolicy
                ? ScheduleAttendancePolicy(
                    checkInStartAt: startsAt,
                    onTimeEndAt: startsAt.addingTimeInterval(600),
                    lateEndAt: startsAt.addingTimeInterval(1_800)
                )
                : nil
        )
    }
}

private struct StubAuthorizationUseCase: AuthorizationUseCaseProtocol {

    let permissions: Set<AuthorizationPermissionType>
    let shouldFail: Bool

    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: String
    ) async throws -> ResourcePermission {
        if shouldFail { throw DomainError.custom(message: "권한 조회 실패") }
        return ResourcePermission(
            resourceType: resourceType,
            resourceId: resourceId,
            grantedPermissions: permissions
        )
    }
}

private struct StubDeleteScheduleUseCase: DeleteScheduleUseCaseProtocol {

    let error: Error?

    func execute(scheduleId: String) async throws {
        if let error { throw error }
    }
}

private struct StubForceDeleteScheduleUseCase: ForceDeleteScheduleUseCaseProtocol {
    func execute(scheduleId: String) async throws {}
}
