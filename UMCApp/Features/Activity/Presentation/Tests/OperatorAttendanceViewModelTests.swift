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

/// 조건이 만족될 때까지 MainActor 를 양보하며 대기한다(무한 루프 방지 상한 포함).
///
/// 게이트로 suspend 된 fetch 가 mock 의 호출 기록을 남길 때까지 기다리는 용도.
@MainActor
private func drainUntil(maxYields: Int = 10_000, _ condition: () -> Bool) async {
    var yields = 0
    while !condition(), yields < maxYields {
        await Task.yield()
        yields += 1
    }
}

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

    // MARK: 게이트 (동시성 테스트용) — true 면 해당 fetch 가 release 될 때까지 suspend
    var gateList = false
    var gateDetail = false
    private var listWaiters: [CheckedContinuation<Void, Never>] = []
    private var detailWaiters: [String: CheckedContinuation<Void, Never>] = [:]

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

    @Test("기간 프리셋 선택 → periodPreset 갱신 + 재조회, custom 은 날짜 유지")
    func presetSelectionUpdatesAndRefetches() async {
        let useCase = MockOperatorAttendanceUseCase()
        let viewModel = makeViewModel(useCase: useCase)

        await viewModel.presetSelected(.oneWeek)
        #expect(viewModel.periodPreset == .oneWeek)
        #expect(useCase.fetchListCalls.count == 1)
        #expect(viewModel.fromDate < viewModel.toDate)

        let keptFrom = viewModel.fromDate
        await viewModel.presetSelected(.custom)
        #expect(viewModel.periodPreset == .custom)
        #expect(viewModel.fromDate == keptFrom)
        #expect(useCase.fetchListCalls.count == 2)
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

    @Test("전체 승인 → 승인 대기 전원 present 로 갱신 (확정 상태는 미변경)")
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

        let statuses = (viewModel.detailState.value?.participants ?? [])
            .map(\.attendanceStatus)
        #expect(statuses == [.present, .present, .absent])
        #expect(useCase.decideCalls.first?.decisions.count == 2)
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

#endif
