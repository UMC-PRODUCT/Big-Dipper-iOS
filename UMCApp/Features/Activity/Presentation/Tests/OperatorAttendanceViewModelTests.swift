//
//  OperatorAttendanceViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 7/14/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityPresentation

#if DEBUG

// MARK: - Helpers

private func makeParticipant(
    memberId: String = "1",
    name: String = "김미주",
    status: ParticipantAttendanceStatus = .present
) -> ParticipantAttendance {
    ParticipantAttendance(
        memberId: memberId,
        name: name,
        nickname: name,
        profileImageURL: "",
        schoolId: "1",
        schoolName: "한성대학교",
        attendanceStatus: status,
        isLocationVerified: true,
        excuseReason: nil
    )
}

private func makeScheduleInfo(
    scheduleId: String = "100",
    pendingCount: Int = 0,
    participants: [ParticipantAttendance] = []
) -> ScheduleAttendanceInfo {
    let filled: [ParticipantAttendance] = participants.isEmpty
        ? (0..<pendingCount).map {
            makeParticipant(memberId: "p\($0)", status: .presentPending)
        }
        : participants
    return ScheduleAttendanceInfo(
        scheduleId: scheduleId,
        name: "정기 세션",
        description: "",
        startsAt: Date(timeIntervalSince1970: 1_000),
        endsAt: Date(timeIntervalSince1970: 8_000),
        location: nil,
        isOnline: true,
        authorMemberId: "1",
        attendancePolicy: nil,
        tags: [],
        participants: filled
    )
}

@MainActor
private func makeViewModel(
    useCase: MockOperatorAttendanceUseCase,
    errorHandler: ErrorHandler = ErrorHandler()
) -> OperatorAttendanceViewModel {
    OperatorAttendanceViewModel(errorHandler: errorHandler, useCase: useCase)
}

private enum TestError: Error, Equatable {
    case boom
}

// drainUntil 은 Tests 타깃 공용 `ConcurrencyTestSupport.swift` 의 헬퍼를 사용한다.

// MARK: - Mock

/// 운영진 출석 UseCase Mock.
///
/// `@MainActor` — VM(@MainActor)이 프로토콜 메서드를 호출할 때 액터 홉 없이 실행돼 호출 기록과
/// 게이트 continuation 접근이 메인 액터에서 직렬화된다(동시성 테스트의 데이터 레이스 방지).
@MainActor
private final class MockOperatorAttendanceUseCase: OperatorAttendanceUseCaseProtocol {

    // MARK: 스텁 결과
    var fetchListResult: [ScheduleAttendanceInfo] = []
    /// 호출 순서대로 소비하는 목록 결과(없으면 `fetchListResult` 폴백).
    var fetchListResultQueue: [[ScheduleAttendanceInfo]] = []
    var fetchDetailResult: ScheduleAttendanceInfo = makeScheduleInfo()
    /// scheduleId 별 상세 결과(없으면 `fetchDetailResult` 폴백).
    var fetchDetailResultByScheduleId: [String: ScheduleAttendanceInfo] = [:]
    var decideResult: [AttendanceDecisionResult] = []

    // MARK: 메서드별 에러
    var fetchListError: Error?
    var fetchDetailError: Error?
    var decideError: Error?
    var updateLocationError: Error?

    // MARK: 게이트 (동시성 테스트용) — true 면 해당 요청이 release 될 때까지 suspend
    var gateList = false
    var gateDetail = false
    var gateDecide = false
    private var listWaiters: [CheckedContinuation<Void, Never>] = []
    private var detailWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var decideWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: 호출 기록
    private(set) var fetchListCalls: [(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    )] = []
    private(set) var fetchDetailCalls: [(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    )] = []
    private(set) var decideCalls: [(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    )] = []
    private(set) var updateLocationCalls: [(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    )] = []
    private var listCallIndex = 0

    func fetchAttendanceList(
        from: Date?,
        to: Date?,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> [ScheduleAttendanceInfo] {
        // 결과 인덱스는 게이트 대기 전에 고정 — release 순서와 무관하게 결정론적.
        let index = listCallIndex
        listCallIndex += 1
        fetchListCalls.append((from, to, attendanceStatus))
        if gateList {
            await withCheckedContinuation { listWaiters.append($0) }
        }
        if let fetchListError { throw fetchListError }
        return index < fetchListResultQueue.count ? fetchListResultQueue[index] : fetchListResult
    }

    func fetchAttendanceDetail(
        scheduleId: String,
        attendanceStatus: ParticipantAttendanceStatus?
    ) async throws -> ScheduleAttendanceInfo {
        fetchDetailCalls.append((scheduleId, attendanceStatus))
        if gateDetail {
            await withCheckedContinuation { detailWaiters[scheduleId] = $0 }
        }
        if let fetchDetailError { throw fetchDetailError }
        return fetchDetailResultByScheduleId[scheduleId] ?? fetchDetailResult
    }

    func decideAttendances(
        scheduleId: String,
        decisions: [AttendanceDecisionInput]
    ) async throws -> [AttendanceDecisionResult] {
        decideCalls.append((scheduleId, decisions))
        if gateDecide {
            await withCheckedContinuation { decideWaiters.append($0) }
        }
        if let decideError { throw decideError }
        return decideResult
    }

    func updateScheduleLocation(
        scheduleId: String,
        locationName: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        updateLocationCalls.append((scheduleId, locationName, latitude, longitude))
        if let updateLocationError { throw updateLocationError }
    }

    // MARK: 게이트 해제

    /// 대기 중인 모든 목록 fetch 를 방출한다.
    func releaseList() {
        let waiters = listWaiters
        listWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// 지정한 scheduleId 의 상세 fetch 를 방출한다.
    func releaseDetail(_ scheduleId: String) {
        detailWaiters.removeValue(forKey: scheduleId)?.resume()
    }

    /// 대기 중인 모든 결정 요청을 방출한다.
    func releaseDecide() {
        let waiters = decideWaiters
        decideWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

// MARK: - 목록 조회 / 필터 / 기간

@MainActor
@Suite("OperatorAttendanceViewModel — 목록 조회 (도메인 규칙)")
struct OperatorAttendanceViewModelListTests {

    @Test("목록 조회 성공 → loaded 전이 + 기간/필터 인자 그대로 위임")
    func fetchListSucceedsAndDelegates() async {
        let useCase = MockOperatorAttendanceUseCase()
        let expected = [makeScheduleInfo(scheduleId: "7"), makeScheduleInfo(scheduleId: "8")]
        useCase.fetchListResult = expected
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchList()

        #expect(viewModel.listState == .loaded(expected))
        #expect(useCase.fetchListCalls.count == 1)
        #expect(useCase.fetchListCalls.first?.attendanceStatus == nil)
    }

    @Test("목록 조회 취소(CancellationError) → 이전 상태로 롤백 (실패 아님)")
    func fetchListForwardsCancellation() async {
        let useCase = MockOperatorAttendanceUseCase()
        let first = [makeScheduleInfo(scheduleId: "7")]
        useCase.fetchListResult = first
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchList()

        useCase.fetchListError = CancellationError()
        await viewModel.fetchList()

        // 취소는 실패로 표시되지 않고 직전 loaded 상태를 유지한다.
        #expect(viewModel.listState == .loaded(first))
    }

    @Test("목록 배경 갱신 실패 → 에러를 삼키고 기존 데이터 유지")
    func backgroundListRefreshKeepsDataOnFailure() async {
        let useCase = MockOperatorAttendanceUseCase()
        let loaded = [makeScheduleInfo(scheduleId: "7")]
        useCase.fetchListResult = loaded
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchList()

        useCase.fetchListError = TestError.boom
        await viewModel.refreshList()

        // 배경 경로(showLoading=false)는 실패해도 화면을 에러로 전이시키지 않는다.
        #expect(viewModel.listState == .loaded(loaded))
    }

    @Test("목록 조회 실패(DomainError) → failed(.domain) 전이")
    func fetchListFailsWithDomainError() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchListError = DomainError.custom(message: "실패")
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchList()

        #expect(viewModel.listState == .failed(.domain(.custom(message: "실패"))))
    }

    @Test("목록 조회 403 → failed(.network) + isPermissionDenied == true")
    func fetchListPermissionDeniedOn403() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchListError = NetworkError.requestFailed(statusCode: 403, data: nil)
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchList()

        #expect(viewModel.isPermissionDenied == true)
    }

    @Test("상태 필터 탭 → 필터 설정 + 재조회, 같은 필터 재탭 → 해제")
    func listFilterTogglesAndRefetches() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.listFilterButtonTapped(.presentPending)
        #expect(viewModel.selectedListFilter == .presentPending)
        #expect(useCase.fetchListCalls.last?.attendanceStatus == .presentPending)

        await viewModel.listFilterButtonTapped(.presentPending)
        #expect(viewModel.selectedListFilter == nil)
        #expect(useCase.fetchListCalls.count == 2)
    }

    @Test("전체 필터 초기화 — 이미 전체면 재조회하지 않음")
    func clearListFilterSkipsWhenAlreadyAll() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.clearListFilter()

        #expect(useCase.fetchListCalls.isEmpty)
    }

    @Test("기간 프리셋 선택 → periodPreset 갱신 + 재조회, custom 은 날짜 유지·재조회 없음")
    func presetSelectionUpdatesAndRefetches() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.presetSelected(.oneWeek)
        #expect(viewModel.periodPreset == .oneWeek)
        #expect(useCase.fetchListCalls.count == 1)
        #expect(viewModel.fromDate < viewModel.toDate)

        // .custom 은 범위가 그대로라 동일 조건 재조회를 만들지 않는다 (사용자 조정 후 조회).
        let keptFrom = viewModel.fromDate
        await viewModel.presetSelected(.custom)
        #expect(viewModel.periodPreset == .custom)
        #expect(viewModel.fromDate == keptFrom)
        #expect(useCase.fetchListCalls.count == 1)
    }

    @Test("승인 대기 파생 상태 — totalPendingCount 합산 + firstPendingScheduleId")
    func pendingDerivedState() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchListResult = [
            makeScheduleInfo(scheduleId: "10", pendingCount: 0),
            makeScheduleInfo(scheduleId: "11", pendingCount: 2),
            makeScheduleInfo(scheduleId: "12", pendingCount: 3)
        ]
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchList()

        #expect(viewModel.totalPendingCount == 5)
        #expect(viewModel.firstPendingScheduleId == "11")
    }
}

// MARK: - 상세 조회 / 필터

@MainActor
@Suite("OperatorAttendanceViewModel — 상세 조회 (도메인 규칙)")
struct OperatorAttendanceViewModelDetailTests {

    @Test("일정 선택 → scheduleId 지정 + 상세 조회 위임")
    func selectScheduleFetchesDetail() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42")
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.selectSchedule("42")

        #expect(viewModel.selectedScheduleId == "42")
        #expect(useCase.fetchDetailCalls.first?.scheduleId == "42")
        #expect(viewModel.detailState == .loaded(makeScheduleInfo(scheduleId: "42")))
    }

    @Test("선택 없이 상세 조회 → 아무 동작 없음")
    func fetchDetailWithoutSelectionIsNoOp() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.fetchDetail()

        #expect(useCase.fetchDetailCalls.isEmpty)
        #expect(viewModel.detailState == .idle)
    }

    @Test("상세 조회 중 일정 삭제(SCHEDULE-0009) → isScheduleDeleted + failed(.repository)")
    func fetchDetailDetectsDeletedSchedule() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailError = RepositoryError.serverError(
            code: "SCHEDULE-0009",
            message: "삭제된 일정"
        )
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.selectSchedule("42")

        #expect(viewModel.isScheduleDeleted == true)
        #expect(viewModel.detailState.error != nil)
    }

    @Test("상세 조회 취소 → 이전 상태로 롤백")
    func fetchDetailForwardsCancellation() async {
        let useCase = MockOperatorAttendanceUseCase()
        let loaded = makeScheduleInfo(scheduleId: "42")
        useCase.fetchDetailResult = loaded
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        useCase.fetchDetailError = CancellationError()
        await viewModel.fetchDetail()

        #expect(viewModel.detailState == .loaded(loaded))
    }

    @Test("배경 갱신 중 일정 삭제(SCHEDULE-0009) → isScheduleDeleted 감지")
    func backgroundRefreshDetectsDeletedSchedule() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42")
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        // 폴링과 같은 배경 경로(refreshDetail)에서도 삭제가 감지돼야 stale 화면이 남지 않는다.
        useCase.fetchDetailError = RepositoryError.serverError(
            code: "SCHEDULE-0009",
            message: "삭제된 일정"
        )
        await viewModel.refreshDetail()

        #expect(viewModel.isScheduleDeleted == true)
        #expect(viewModel.detailState.error != nil)
    }

    @Test("삭제 상태에서 재조회가 취소되면 isScheduleDeleted 도 페어로 복원된다")
    func cancellationRestoresScheduleDeletedFlag() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailError = RepositoryError.serverError(
            code: "SCHEDULE-0009",
            message: "삭제된 일정"
        )
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")
        #expect(viewModel.isScheduleDeleted == true)

        useCase.fetchDetailError = CancellationError()
        await viewModel.fetchDetail()

        // 취소는 실패가 아니므로 상태와 삭제 플래그가 함께 이전 값으로 돌아온다.
        #expect(viewModel.isScheduleDeleted == true)
        #expect(viewModel.detailState.error != nil)
    }

    @Test("일정 전환 → 이전 일정 기준 확인 다이얼로그가 닫힌다")
    func selectScheduleDismissesAlertPrompt() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "A", participants: [pending])
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("A")

        viewModel.approveButtonTapped(participant: pending)
        #expect(viewModel.alertPrompt != nil)

        await viewModel.selectSchedule("B")
        #expect(viewModel.alertPrompt == nil)
    }

    @Test("상세 상태 필터 → 클라이언트 측 필터링, 재탭 시 해제")
    func detailFilterFiltersClientSide() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailResult = makeScheduleInfo(
            scheduleId: "42",
            participants: [
                makeParticipant(memberId: "1", status: .present),
                makeParticipant(memberId: "2", status: .absent),
                makeParticipant(memberId: "3", status: .present)
            ]
        )
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        viewModel.detailFilterButtonTapped(.present)
        #expect(viewModel.filteredParticipants.map(\.memberId) == ["1", "3"])

        viewModel.detailFilterButtonTapped(.present)
        #expect(viewModel.filteredParticipants.count == 3)
    }
}

// MARK: - 승인 / 반려 (낙관적 갱신)

@MainActor
@Suite("OperatorAttendanceViewModel — 승인/반려 (도메인 규칙)")
struct OperatorAttendanceViewModelDecisionTests {

    private func loadedViewModel(
        useCase: MockOperatorAttendanceUseCase,
        participants: [ParticipantAttendance]
    ) async -> OperatorAttendanceViewModel {
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42", participants: participants)
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")
        return viewModel
    }

    @Test(
        "단건 결정 성공 → 대상만 낙관적 갱신 (승인=present / 반려=absent)",
        arguments: [true, false]
    )
    func decideSingleUpdatesTargetOptimistically(isApproved: Bool) async {
        let useCase = MockOperatorAttendanceUseCase()
        let target = makeParticipant(memberId: "1", status: .presentPending)
        let other = makeParticipant(memberId: "2", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [target, other])

        await viewModel.decideAttendance(participant: target, isApproved: isApproved)

        let participants = viewModel.detailState.value?.participants ?? []
        let updated = participants.first { $0.memberId == "1" }
        let untouched = participants.first { $0.memberId == "2" }
        #expect(updated?.attendanceStatus == (isApproved ? .present : .absent))
        #expect(untouched?.attendanceStatus == .presentPending)
        #expect(useCase.decideCalls.first?.scheduleId == "42")
        #expect(useCase.decideCalls.first?.decisions.first?.participantMemberId == "1")
    }

    @Test("전체 승인 → 승인 대기 전원만 대기 종류를 보존해 갱신 (확정 상태는 미변경)")
    func decideAllApprovesPendingOnly() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pendingA = makeParticipant(memberId: "1", status: .presentPending)
        let pendingB = makeParticipant(memberId: "2", status: .latePending)
        let confirmed = makeParticipant(memberId: "3", status: .absent)
        let viewModel = await loadedViewModel(
            useCase: useCase,
            participants: [pendingA, pendingB, confirmed]
        )

        await viewModel.decideAllAttendances(isApproved: true)

        // 지각 승인 대기는 '지각' 으로 확정된다 (일괄 present 로 뭉개지 않음).
        let statuses = (viewModel.detailState.value?.participants ?? [])
            .map(\.attendanceStatus)
        #expect(statuses == [.present, .late, .absent])
        #expect(useCase.decideCalls.first?.decisions.count == 2)
    }

    @Test(
        "승인 확정 상태는 대기 종류를 보존하고, 반려는 일괄 absent 로 확정한다",
        arguments: [
            (pending: ParticipantAttendanceStatus.presentPending, isApproved: true,
             expected: ParticipantAttendanceStatus.present),
            (pending: .latePending, isApproved: true, expected: .late),
            (pending: .excusedPending, isApproved: true, expected: .excused),
            (pending: .presentPending, isApproved: false, expected: .absent),
            (pending: .latePending, isApproved: false, expected: .absent),
            (pending: .excusedPending, isApproved: false, expected: .absent)
        ]
    )
    func decidedStatusPreservesPendingKind(
        testCase: (
            pending: ParticipantAttendanceStatus,
            isApproved: Bool,
            expected: ParticipantAttendanceStatus
        )
    ) async {
        let useCase = MockOperatorAttendanceUseCase()
        let target = makeParticipant(memberId: "1", status: testCase.pending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [target])

        await viewModel.decideAttendance(participant: target, isApproved: testCase.isApproved)

        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == testCase.expected)
    }

    @Test("결정 성공 → 목록의 같은 일정 항목도 갱신 (승인 대기 배지 즉시 반영)")
    func decideUpdatesMatchingListEntry() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        let schedule = makeScheduleInfo(scheduleId: "42", participants: [pending])
        useCase.fetchListResult = [schedule, makeScheduleInfo(scheduleId: "43", pendingCount: 1)]
        useCase.fetchDetailResult = schedule
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchList()
        await viewModel.selectSchedule("42")

        await viewModel.decideAttendance(participant: pending, isApproved: true)

        // 결정한 일정의 배지만 줄고 다른 일정 항목은 그대로 유지된다.
        let entries = viewModel.listState.value ?? []
        #expect(entries.first { $0.scheduleId == "42" }?.pendingCount == 0)
        #expect(entries.first { $0.scheduleId == "43" }?.pendingCount == 1)
        #expect(viewModel.totalPendingCount == 1)
    }

    @Test("선택 결정 → 선택한 참여자만 갱신")
    func decideSelectedUpdatesOnlySelected() async {
        let useCase = MockOperatorAttendanceUseCase()
        let a = makeParticipant(memberId: "1", status: .presentPending)
        let b = makeParticipant(memberId: "2", status: .presentPending)
        let c = makeParticipant(memberId: "3", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [a, b, c])

        await viewModel.decideSelectedAttendances(participants: [a, c], isApproved: true)

        let byId = Dictionary(
            uniqueKeysWithValues: (viewModel.detailState.value?.participants ?? [])
                .map { ($0.memberId, $0.attendanceStatus) }
        )
        #expect(byId["1"] == .present)
        #expect(byId["2"] == .presentPending)
        #expect(byId["3"] == .present)
    }

    @Test("결정 403 → 권한 Alert + 상세 재조회, 낙관적 갱신 미적용")
    func decidePermissionDeniedShowsAlertAndRefreshes() async {
        let useCase = MockOperatorAttendanceUseCase()
        let target = makeParticipant(memberId: "1", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [target])
        useCase.decideError = NetworkError.requestFailed(statusCode: 403, data: nil)

        await viewModel.decideAttendance(participant: target, isApproved: true)

        #expect(viewModel.alertPrompt?.title == "권한이 없어요")
        // 초기 선택 조회 1회 + 실패 후 refreshDetail 1회 = 2회
        #expect(useCase.fetchDetailCalls.count == 2)
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("결정 비-권한 에러 → errorHandler 경로 (Alert 없음, 갱신 미적용)")
    func decideNonPermissionErrorRoutesToHandler() async {
        let useCase = MockOperatorAttendanceUseCase()
        let target = makeParticipant(memberId: "1", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [target])
        useCase.decideError = TestError.boom

        await viewModel.decideAttendance(participant: target, isApproved: true)

        #expect(viewModel.alertPrompt == nil)
        #expect(useCase.fetchDetailCalls.count == 1)
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("전체 결정 403 → 권한 Alert (단건과 동일 에러 경로, 형제 대칭)")
    func decideAllPermissionDeniedShowsAlert() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [pending])
        useCase.decideError = NetworkError.requestFailed(statusCode: 403, data: nil)

        await viewModel.decideAllAttendances(isApproved: true)

        #expect(viewModel.alertPrompt?.title == "권한이 없어요")
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("선택 결정 403 → 권한 Alert (단건과 동일 에러 경로, 형제 대칭)")
    func decideSelectedPermissionDeniedShowsAlert() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        let viewModel = await loadedViewModel(useCase: useCase, participants: [pending])
        useCase.decideError = NetworkError.requestFailed(statusCode: 403, data: nil)

        await viewModel.decideSelectedAttendances(participants: [pending], isApproved: true)

        #expect(viewModel.alertPrompt?.title == "권한이 없어요")
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("선택 없이 결정 → UseCase 미호출")
    func decideWithoutSelectionIsNoOp() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.decideAttendance(
            participant: makeParticipant(memberId: "1"),
            isApproved: true
        )

        #expect(useCase.decideCalls.isEmpty)
    }
}

// MARK: - 위치 변경

@MainActor
@Suite("OperatorAttendanceViewModel — 위치 변경 (도메인 규칙)")
struct OperatorAttendanceViewModelLocationTests {

    private func selectedViewModel(
        useCase: MockOperatorAttendanceUseCase
    ) async -> OperatorAttendanceViewModel {
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42")
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")
        return viewModel
    }

    @Test("위치 변경 — 빈 이름은 거부 + Alert, UseCase 미호출")
    func changeLocationRejectsEmptyName() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = await selectedViewModel(useCase: useCase)

        let result = await viewModel.changeLocation(name: "   ", latitude: 37.5, longitude: 127.0)

        #expect(result == false)
        #expect(viewModel.alertPrompt != nil)
        #expect(useCase.updateLocationCalls.isEmpty)
    }

    @Test(
        "위치 변경 — 유효하지 않은 좌표는 거부",
        arguments: [
            (lat: 91.0, lng: 127.0),
            (lat: 37.5, lng: 181.0),
            (lat: Double.nan, lng: 127.0)
        ]
    )
    func changeLocationRejectsInvalidCoordinate(lat: Double, lng: Double) async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = await selectedViewModel(useCase: useCase)

        let result = await viewModel.changeLocation(name: "한성대", latitude: lat, longitude: lng)

        #expect(result == false)
        #expect(useCase.updateLocationCalls.isEmpty)
    }

    @Test("위치 변경 성공 → 이름 트림 + 좌표 그대로 위임")
    func changeLocationSucceedsAndDelegates() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = await selectedViewModel(useCase: useCase)

        let result = await viewModel.changeLocation(
            name: "  한성대 상상관  ",
            latitude: 37.582,
            longitude: 127.010
        )

        #expect(result == true)
        let call = useCase.updateLocationCalls.first
        #expect(call?.scheduleId == "42")
        #expect(call?.locationName == "한성대 상상관")
        #expect(call?.latitude == 37.582)
        #expect(call?.longitude == 127.010)
    }

    @Test("위치 변경 성공 → 상세 화면 위치가 재조회 없이 즉시 교체된다")
    func changeLocationUpdatesDetailState() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = await selectedViewModel(useCase: useCase)

        let result = await viewModel.changeLocation(
            name: "한성대 상상관",
            latitude: 37.582,
            longitude: 127.010
        )

        #expect(result == true)
        let location = viewModel.detailState.value?.location
        #expect(location?.locationName == "한성대 상상관")
        #expect(location?.latitude == 37.582)
        #expect(location?.longitude == 127.010)
    }

    @Test("위치 변경 에러 → false 반환 (errorHandler 경로)")
    func changeLocationForwardsErrorReturnsFalse() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = await selectedViewModel(useCase: useCase)
        useCase.updateLocationError = TestError.boom

        let result = await viewModel.changeLocation(
            name: "한성대",
            latitude: 37.5,
            longitude: 127.0
        )

        #expect(result == false)
    }

    @Test("선택 없이 위치 변경 → false + UseCase 미호출")
    func changeLocationWithoutSelectionReturnsFalse() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        let result = await viewModel.changeLocation(
            name: "한성대",
            latitude: 37.5,
            longitude: 127.0
        )

        #expect(result == false)
        #expect(useCase.updateLocationCalls.isEmpty)
    }
}

// MARK: - 요청 토큰 latest-wins (동시성)

@MainActor
@Suite("OperatorAttendanceViewModel — 요청 토큰 latest-wins (도메인 규칙)")
struct OperatorAttendanceViewModelRequestTokenTests {

    @Test("상세 스케줄 전환 — 진행 중 이전 스케줄 응답이 새 식별자에 바인딩되지 않는다")
    func detailScheduleSwitchDiscardsStaleResponse() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.gateDetail = true
        useCase.fetchDetailResultByScheduleId = [
            "A": makeScheduleInfo(
                scheduleId: "A",
                participants: [makeParticipant(memberId: "a1")]
            ),
            "B": makeScheduleInfo(
                scheduleId: "B",
                participants: [makeParticipant(memberId: "b1")]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)

        // A 상세 조회 시작 → 게이트에서 대기
        let selectA = Task { await viewModel.selectSchedule("A") }
        await drainUntil { useCase.fetchDetailCalls.contains { $0.scheduleId == "A" } }

        // B 로 전환 → 게이트에서 대기 (재진입 가드였다면 여기서 유실됐을 요청)
        let selectB = Task { await viewModel.selectSchedule("B") }
        await drainUntil { useCase.fetchDetailCalls.contains { $0.scheduleId == "B" } }

        // 오래된 A 응답을 먼저 방출 → 토큰 불일치로 폐기돼야 함
        useCase.releaseDetail("A")
        await selectA.value
        // 최신 B 응답 방출 → 반영
        useCase.releaseDetail("B")
        await selectB.value

        #expect(viewModel.selectedScheduleId == "B")
        #expect(viewModel.detailState.value?.scheduleId == "B")
        #expect(viewModel.detailState.value?.participants.map(\.memberId) == ["b1"])
    }

    @Test("목록 필터 변경 — 진행 중 언필터 응답이 필터 상태를 덮어쓰지 않는다")
    func listFilterChangeDiscardsStaleResponse() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.gateList = true
        let unfiltered = [makeScheduleInfo(scheduleId: "1"), makeScheduleInfo(scheduleId: "2")]
        let filtered = [makeScheduleInfo(scheduleId: "1")]
        useCase.fetchListResultQueue = [unfiltered, filtered]
        let viewModel = makeViewModel(useCase: useCase)

        // 초기(언필터) 조회 시작 → 게이트 대기
        let initial = Task { await viewModel.fetchList() }
        await drainUntil { useCase.fetchListCalls.count == 1 }

        // 필터 변경 → 두 번째(필터) 조회 시작, 게이트 대기
        let filterTap = Task { await viewModel.listFilterButtonTapped(.presentPending) }
        await drainUntil { useCase.fetchListCalls.count == 2 }

        // 두 응답 모두 방출 → 오래된 언필터 응답은 토큰으로 폐기
        useCase.releaseList()
        await initial.value
        await filterTap.value

        #expect(viewModel.selectedListFilter == .presentPending)
        #expect(viewModel.listState == .loaded(filtered))
        #expect(useCase.fetchListCalls.last?.attendanceStatus == .presentPending)
    }
}

// MARK: - 일정 정체성 가드 (mutation 동시성)

@MainActor
@Suite("OperatorAttendanceViewModel — 일정 정체성 가드 (도메인 규칙)")
struct OperatorAttendanceViewModelScheduleIdentityTests {

    @Test("결정 진행 중 일정 전환 → 낙관적 갱신이 전환된 일정으로 새지 않는다")
    func decideDuringScheduleSwitchDoesNotLeak() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pendingA = makeParticipant(memberId: "1", status: .presentPending)
        let pendingB = makeParticipant(memberId: "1", status: .presentPending)
        useCase.fetchDetailResultByScheduleId = [
            "A": makeScheduleInfo(scheduleId: "A", participants: [pendingA]),
            "B": makeScheduleInfo(scheduleId: "B", participants: [pendingB])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("A")

        // A 에 대한 결정을 게이트로 붙잡은 상태에서 B 로 전환한다.
        useCase.gateDecide = true
        let decision = Task {
            await viewModel.decideAttendance(participant: pendingA, isApproved: true)
        }
        await drainUntil { useCase.decideCalls.count == 1 }
        await viewModel.selectSchedule("B")

        useCase.releaseDecide()
        await decision.value

        // 결정은 A 엔드포인트로 나갔고, B 화면의 같은 memberId 는 여전히 승인 대기다.
        #expect(useCase.decideCalls.first?.scheduleId == "A")
        #expect(viewModel.detailState.value?.scheduleId == "B")
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("결정 성공 → in-flight 폴 응답(결정 이전 스냅샷)이 낙관적 갱신을 되돌리지 못한다")
    func decideInvalidatesInFlightPollResponse() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42", participants: [pending])
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        // 폴 fetch 를 게이트로 붙잡아 in-flight 로 만든다 (응답은 결정 이전 스냅샷).
        useCase.gateDetail = true
        let poll = Task { await viewModel.refreshDetail() }
        await drainUntil { useCase.fetchDetailCalls.count == 2 }

        await viewModel.decideAttendance(participant: pending, isApproved: true)
        useCase.releaseDetail("42")
        await poll.value

        // 폴 응답이 pending 스냅샷으로 되돌리지 않고 낙관적 갱신이 살아남는다.
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .present)
    }

    @Test("전체 승인 Alert — 실행 시점이 아니라 탭 시점의 일정·대상으로 결정을 보낸다")
    func approveAllCapturesScheduleAtTapTime() async {
        let useCase = MockOperatorAttendanceUseCase()
        useCase.fetchDetailResultByScheduleId = [
            "A": makeScheduleInfo(
                scheduleId: "A",
                participants: [makeParticipant(memberId: "a1", status: .presentPending)]
            ),
            "B": makeScheduleInfo(
                scheduleId: "B",
                participants: [makeParticipant(memberId: "b1", status: .presentPending)]
            )
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("A")

        // A 화면에서 Alert 를 띄운 뒤(액션 캡처) B 로 전환하고 나서 확인 액션을 실행한다.
        viewModel.approveAllButtonTapped()
        let confirmAction = viewModel.alertPrompt?.positiveBtnAction
        await viewModel.selectSchedule("B")

        confirmAction?()
        await drainUntil { useCase.decideCalls.count == 1 }
        await drainUntil { viewModel.processingMemberIds.isEmpty }

        // 결정은 탭 시점의 A 일정·A 대상에게 전송되고, B 화면은 건드리지 않는다.
        #expect(useCase.decideCalls.first?.scheduleId == "A")
        #expect(useCase.decideCalls.first?.decisions.map(\.participantMemberId) == ["a1"])
        let status = viewModel.detailState.value?.participants.first?.attendanceStatus
        #expect(status == .presentPending)
    }

    @Test("결정 성공 — 같은 일정의 스피너 로드가 진행 중이면 토큰을 올리지 않아 로드가 살아남는다")
    func decideDoesNotOrphanInFlightSpinnerLoad() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        useCase.fetchDetailResultByScheduleId = [
            "A": makeScheduleInfo(scheduleId: "A", participants: [pending])
        ]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("A")

        // 결정을 게이트로 붙잡은 채, 같은 일정 A 를 다시 선택해 스피너 로드를 in-flight 로 만든다.
        useCase.gateDecide = true
        let decision = Task {
            await viewModel.decideAttendance(participant: pending, isApproved: true)
        }
        await drainUntil { useCase.decideCalls.count == 1 }
        useCase.gateDetail = true
        let reload = Task { await viewModel.selectSchedule("A") }
        await drainUntil { useCase.fetchDetailCalls.count == 2 }
        #expect(viewModel.detailState.isLoading)

        // 결정이 먼저 성공해도 .loading 중에는 토큰을 올리지 않아 로드 응답이 반영된다.
        useCase.releaseDecide()
        await decision.value
        useCase.releaseDetail("A")
        await reload.value

        #expect(viewModel.detailState.value != nil)
        #expect(viewModel.detailState.isLoading == false)
    }

    @Test("결정 성공 → in-flight 목록 폴 응답이 배지 낙관적 갱신을 되돌리지 못한다")
    func decideInvalidatesInFlightListPollResponse() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        let preDecision = [makeScheduleInfo(scheduleId: "42", participants: [pending])]
        useCase.fetchListResultQueue = [preDecision, preDecision]
        useCase.fetchDetailResult = preDecision[0]
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.fetchList()
        await viewModel.selectSchedule("42")

        // 목록 배경 폴을 게이트로 붙잡아 in-flight 로 만든다 (응답은 결정 이전 스냅샷).
        useCase.gateList = true
        let poll = Task { await viewModel.refreshList() }
        await drainUntil { useCase.fetchListCalls.count == 2 }

        await viewModel.decideAttendance(participant: pending, isApproved: true)
        useCase.releaseList()
        await poll.value

        // 폴 응답이 배지를 '승인 대기 1건' 으로 되돌리지 않는다.
        let entry = viewModel.listState.value?.first { $0.scheduleId == "42" }
        #expect(entry?.pendingCount == 0)
        #expect(viewModel.totalPendingCount == 0)
    }

    @Test("in-flight 대상에 대한 재결정은 무시된다 (중복 전송 방지)")
    func duplicateDecisionForInFlightMemberIsIgnored() async {
        let useCase = MockOperatorAttendanceUseCase()
        let pending = makeParticipant(memberId: "1", status: .presentPending)
        useCase.fetchDetailResult = makeScheduleInfo(scheduleId: "42", participants: [pending])
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        useCase.gateDecide = true
        let first = Task { await viewModel.decideAttendance(participant: pending, isApproved: true) }
        await drainUntil { useCase.decideCalls.count == 1 }

        // 같은 멤버에 대한 두 번째 결정은 서버로 나가지 않는다.
        await viewModel.decideAttendance(participant: pending, isApproved: false)
        #expect(useCase.decideCalls.count == 1)

        useCase.releaseDecide()
        await first.value
        #expect(viewModel.processingMemberIds.isEmpty)
    }

    @Test("배치 결정 진행 중 대상 전원이 processingMemberIds 에 등록·해제된다")
    func batchDecisionTracksProcessingMembers() async {
        let useCase = MockOperatorAttendanceUseCase()
        let first = makeParticipant(memberId: "1", status: .presentPending)
        let second = makeParticipant(memberId: "2", status: .latePending)
        useCase.fetchDetailResult = makeScheduleInfo(
            scheduleId: "42",
            participants: [first, second]
        )
        let viewModel = makeViewModel(useCase: useCase)
        await viewModel.selectSchedule("42")

        useCase.gateDecide = true
        let decision = Task { await viewModel.decideAllAttendances(isApproved: true) }
        await drainUntil { useCase.decideCalls.count == 1 }

        // 진행 중에는 대상 전원이 처리 중으로 표시돼 행별 버튼의 중복 결정을 막는다.
        #expect(viewModel.processingMemberIds == ["1", "2"])

        useCase.releaseDecide()
        await decision.value
        #expect(viewModel.processingMemberIds.isEmpty)
    }
}

#endif
