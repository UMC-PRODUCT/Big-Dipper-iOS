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

// MARK: - Helpers

@MainActor
private func makeViewModel(
    hasAttendancePolicy: Bool,
    isAdminMode: Bool
) -> ScheduleDetailViewModel {
    let container = DIContainer()
    container.register(FetchScheduleDetailUseCaseProtocol.self) {
        StubFetchScheduleDetailUseCase(hasAttendancePolicy: hasAttendancePolicy)
    }
    container.register(UserSessionManager.self) { makeSession(isAdminMode: isAdminMode) }
    return ScheduleDetailViewModel(container: container, scheduleId: "1")
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
