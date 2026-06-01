//
//  AttendanceListViewModelTests.swift
//  AppProductTests
//
//  출석 현황 목록 ViewModel 의 기능 로직 검증.
//  - "전체" 칩(clearFilter) 동작 및 회귀 방지
//  - 상태 필터 토글
//  - "승인 대기" 배너 네비게이션 보장(firstPendingScheduleId)
//

@testable import AppProduct
import Foundation
import Testing

struct AttendanceListViewModelTests {

    // MARK: - Fixtures

    private func participant(
        memberId: Int,
        status: AttendanceStatusV2
    ) -> ParticipantAttendance {
        ParticipantAttendance(
            memberId: memberId,
            name: "멤버\(memberId)",
            nickname: "닉\(memberId)",
            profileImageUrl: "",
            schoolId: 1,
            schoolName: "테스트대학교",
            attendanceStatus: status,
            isLocationVerified: true,
            excuseReason: nil
        )
    }

    private func schedule(
        scheduleId: Int,
        participants: [ParticipantAttendance]
    ) -> ScheduleAttendanceInfo {
        ScheduleAttendanceInfo(
            scheduleId: scheduleId,
            name: "일정\(scheduleId)",
            description: "",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            location: nil,
            isOnline: false,
            authorMemberId: 1,
            attendancePolicy: nil,
            tags: [],
            participants: participants
        )
    }

    @MainActor
    private func makeViewModel(list: [ScheduleAttendanceInfo]) -> AttendanceListViewModel {
        AttendanceListViewModel(
            container: DIContainer(),
            errorHandler: ErrorHandler(),
            useCase: StubOperatorAttendanceUseCase(list: list)
        )
    }

    // MARK: - "전체" 칩 (clearFilter) — 필터 버그 수정 검증

    @Test("clearFilter 는 선택된 상태 필터를 해제한다")
    @MainActor
    func clearFilterResetsSelectedFilter() async {
        let vm = makeViewModel(list: [])
        await vm.filterButtonTapped(.presentPending)
        #expect(vm.selectedFilter == .presentPending)

        await vm.clearFilter()
        #expect(vm.selectedFilter == nil)
    }

    @Test("이미 전체(필터 없음) 상태에서 clearFilter 는 다른 필터로 바뀌지 않는다 (#버그 회귀 방지)")
    @MainActor
    func clearFilterIsNoOpWhenAlreadyAll() async {
        let vm = makeViewModel(list: [])
        #expect(vm.selectedFilter == nil)

        await vm.clearFilter()
        // 과거 버그(filterButtonTapped(selectedFilter ?? .present))였다면 여기서 .presentPending 으로
        // 잘못 전환됐을 것. clearFilter 는 전체 상태를 그대로 유지해야 한다.
        #expect(vm.selectedFilter == nil)
    }

    @Test("filterButtonTapped 는 같은 필터를 다시 누르면 해제(토글)한다")
    @MainActor
    func filterButtonTogglesSelection() async {
        let vm = makeViewModel(list: [])
        await vm.filterButtonTapped(.late)
        #expect(vm.selectedFilter == .late)

        await vm.filterButtonTapped(.late)
        #expect(vm.selectedFilter == nil)
    }

    // MARK: - "승인 대기" 배너 네비게이션 로직 검증

    @Test("승인 대기 건이 있으면 firstPendingScheduleId 는 첫 번째 대기 일정 id 를 반환한다")
    @MainActor
    func firstPendingScheduleIdReturnsPendingSchedule() async {
        let noPending = schedule(
            scheduleId: 102,
            participants: [participant(memberId: 3, status: .present)]
        )
        let pending = schedule(
            scheduleId: 101,
            participants: [
                participant(memberId: 1, status: .presentPending),
                participant(memberId: 2, status: .present)
            ]
        )
        let vm = makeViewModel(list: [noPending, pending])
        await vm.fetch()

        #expect(vm.totalPendingCount == 1)
        // 배너의 guard(firstPendingScheduleId)가 통과해 올바른 일정(101)으로 push 됨을 보장
        #expect(vm.firstPendingScheduleId == 101)
    }

    @Test("배너 노출 조건(totalPendingCount>0)이면 firstPendingScheduleId 는 항상 non-nil 이다")
    @MainActor
    func bannerInvariantPendingImpliesNonNilScheduleId() async {
        let vm = makeViewModel(list: [
            schedule(scheduleId: 201, participants: [
                participant(memberId: 10, status: .latePending),
                participant(memberId: 11, status: .excusedPending)
            ])
        ])
        await vm.fetch()

        #expect(vm.totalPendingCount > 0)
        #expect(vm.firstPendingScheduleId != nil)
    }
}

// MARK: - Stub

private struct StubOperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {
    let list: [ScheduleAttendanceInfo]

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> [ScheduleAttendanceInfo] {
        list
    }

    func fetchAttendanceDetail(
        scheduleId: Int,
        attendanceStatus: AttendanceStatusV2?
    ) async throws -> ScheduleAttendanceInfo {
        guard let match = list.first(where: { $0.scheduleId == scheduleId }) ?? list.first else {
            throw StubError.notFound
        }
        return match
    }

    func decideAttendances(
        scheduleId: Int,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        []
    }

    func updateScheduleLocation(
        scheduleId: Int,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {}
}

private enum StubError: Error { case notFound }
