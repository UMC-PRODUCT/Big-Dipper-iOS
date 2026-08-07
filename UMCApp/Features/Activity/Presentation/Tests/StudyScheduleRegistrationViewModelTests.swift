//
//  StudyScheduleRegistrationViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import Testing
import ActivityDomain
import HomeDomain
import UMCFoundation
@testable import ActivityPresentation

// 이 테스트 파일은 전부 #if DEBUG 전용 Mock 에 의존하므로 본문 전체를 가드한다.
#if DEBUG

// MARK: - Helpers

/// 결정론적 기준 시각 — wall-clock 비의존
private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

private func makeOption(
    id: String = "W-1",
    weekNo: String = "1",
    title: String = "OT"
) -> WeeklyCurriculumOption {
    WeeklyCurriculumOption(weeklyCurriculumId: id, weekNo: weekNo, title: title)
}

private func makeMember(
    memberID: String?,
    name: String = "멤버"
) -> StudyGroupMember {
    StudyGroupMember(
        serverID: memberID ?? "S-0",
        memberID: memberID,
        name: name,
        university: "한성대학교"
    )
}

@MainActor
private func makeViewModel(
    studyName: String = "iOS 스터디",
    studyGroupId: String = "1",
    membersUseCase: MockFetchStudyMembersUseCase = MockFetchStudyMembersUseCase(),
    repository: MockStudyScheduleRepository = MockStudyScheduleRepository(),
    registerUseCase: MockRegisterStudyScheduleUseCase = MockRegisterStudyScheduleUseCase(),
    errorHandler: ErrorHandler = ErrorHandler(),
    currentMemberId: String? = nil
) -> StudyScheduleRegistrationViewModel {
    StudyScheduleRegistrationViewModel(
        studyName: studyName,
        studyGroupId: studyGroupId,
        studyMembersUseCase: membersUseCase,
        studyRepository: repository,
        registerScheduleUseCase: registerUseCase,
        errorHandler: errorHandler,
        currentMemberId: currentMemberId
    )
}

/// `canSubmit == true` 를 만족하는 기본 뷰 모델 (비대면 + 주차 선택 완료)
@MainActor
private func makeReadyViewModel(
    registerUseCase: MockRegisterStudyScheduleUseCase = MockRegisterStudyScheduleUseCase(),
    errorHandler: ErrorHandler = ErrorHandler()
) -> StudyScheduleRegistrationViewModel {
    let viewModel = makeViewModel(registerUseCase: registerUseCase, errorHandler: errorHandler)
    viewModel.isOnline = true
    viewModel.selectedWeeklyOption = makeOption()
    return viewModel
}

private struct DummyError: Error {}

// MARK: - Mocks

private final class MockFetchStudyMembersUseCase: @unchecked Sendable,
    FetchStudyMembersUseCaseProtocol {

    var result: Result<[StudyGroupMember], Error> = .success([])
    private(set) var callCount = 0
    private(set) var lastGroupId: String?

    func fetchStudyGroupMembers(groupId: String) async throws -> [StudyGroupMember] {
        callCount += 1
        lastGroupId = groupId
        return try result.get()
    }
}

/// `StudyRepositoryProtocol` 의 테스트 전용 Mock.
///
/// 본 뷰 모델이 사용하는 `fetchWeeklyCurriculumOptions()` 만 제어 가능한 stub 으로 노출하고,
/// 나머지 메서드는 계약 밖이므로 호출 시 `fatalError` 로 즉시 실패합니다.
private final class MockStudyScheduleRepository: @unchecked Sendable,
    StudyRepositoryProtocol {

    var weeklyOptionsResult: Result<[WeeklyCurriculumOption], Error> = .success([])
    private(set) var fetchWeeklyCurriculumOptionsCallCount = 0

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        fetchWeeklyCurriculumOptionsCallCount += 1
        return try weeklyOptionsResult.get()
    }

    // MARK: 계약 밖 메서드 (호출 시 실패 — 본 뷰 모델은 사용하지 않음)

    func fetchCurriculumOverview() async throws -> CurriculumOverview {
        fatalError("fetchCurriculumOverview 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        fatalError("fetchStudyGroupDetails 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        fatalError("fetchStudyGroupDetailsPage 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        fatalError("fetchStudyGroupDetail 은 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        fatalError("resolveChallengerId 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        fatalError("fetchStudyGroupNames 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        fatalError(
            "fetchStudyMemberSubmissions 는 StudyScheduleRegistrationViewModel 계약 밖입니다."
        )
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        fatalError("createStudyGroup 은 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        fatalError("updateStudyGroup 은 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func deleteStudyGroup(groupId: String) async throws {
        fatalError("deleteStudyGroup 은 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("addStudyGroupMember 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("removeStudyGroupMember 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("addStudyGroupMentor 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("removeStudyGroupMentor 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        fatalError("연결은 RegisterStudyScheduleUseCase 경유이므로 본 Mock 계약 밖입니다.")
    }
}

/// 일정 등록 2단계(생성 → 연결 → 롤백)를 제어하는 Mock.
private final class MockRegisterStudyScheduleUseCase: @unchecked Sendable,
    RegisterStudyScheduleUseCaseProtocol {

    var createResult: Result<String, Error> = .success("SCH-1")
    var linkResult: Result<Void, Error> = .success(())
    var deleteResult: Result<Void, Error> = .success(())

    /// `true` 면 일정 생성이 ``openCreateGate()`` 전까지 반환하지 않는다.
    ///
    /// 등록이 "진행 중" 인 순간을 관찰해야 하는 중복 제출 테스트에서 쓴다. 생성은 MainActor
    /// 밖에서 재개되므로 continuation 등록/해제가 실행자에 걸치지 않도록 플래그 폴링을 쓴다.
    var gateCreate: Bool = false

    private(set) var createdRequests: [ScheduleCreationRequest] = []
    private(set) var linkCalls: [(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    )] = []
    private(set) var deletedScheduleIds: [String] = []

    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String {
        createdRequests.append(request)
        while gateCreate {
            await Task.yield()
        }
        return try createResult.get()
    }

    /// 게이트에 걸려 있던 일정 생성을 재개시킨다.
    func openCreateGate() {
        gateCreate = false
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        linkCalls.append((scheduleId, studyGroupId, weeklyCurriculumId))
        try linkResult.get()
    }

    func deleteSchedule(scheduleId: String) async throws {
        deletedScheduleIds.append(scheduleId)
        try deleteResult.get()
    }
}

// MARK: - 등록 가능 여부 (canSubmit)

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 등록 가능 여부 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelCanSubmitTests {

    @Test("필수 입력 충족 → 등록 가능")
    func readyViewModelIsSubmittable() {
        #expect(makeReadyViewModel().canSubmit == true)
    }

    @Test("스터디명이 공백/개행뿐 → 불가", arguments: ["", "   ", "\n", " \n "])
    func blankStudyNameBlocksSubmit(name: String) {
        let viewModel = makeReadyViewModel()
        viewModel.studyName = name
        #expect(viewModel.canSubmit == false)
    }

    @Test("대면인데 장소가 공백/개행뿐 → 불가", arguments: ["", "   ", "\n", " \n "])
    func inPersonWithBlankPlaceBlocksSubmit(place: String) {
        let viewModel = makeReadyViewModel()
        viewModel.isOnline = false
        viewModel.placeName = place
        viewModel.placeCoordinate = Coordinate(latitude: 37.5, longitude: 127.0)
        #expect(viewModel.canSubmit == false)
    }

    @Test("대면인데 좌표 미선택 → 불가 (지오펜스 기준점이 없으므로)")
    func inPersonWithoutCoordinateBlocksSubmit() {
        let viewModel = makeReadyViewModel()
        viewModel.isOnline = false
        viewModel.placeName = "한성대 상상관"
        #expect(viewModel.canSubmit == false)
    }

    @Test("대면 + 장소명 + 좌표 → 가능")
    func inPersonWithPlaceAllowsSubmit() {
        let viewModel = makeReadyViewModel()
        viewModel.isOnline = false
        viewModel.placeName = "한성대 상상관"
        viewModel.placeCoordinate = Coordinate(latitude: 37.5, longitude: 127.0)
        #expect(viewModel.canSubmit == true)
    }

    @Test("스터디 그룹 ID 가 비어 있음 → 불가")
    func emptyStudyGroupIdBlocksSubmit() {
        let viewModel = makeViewModel(studyGroupId: "")
        viewModel.isOnline = true
        viewModel.selectedWeeklyOption = makeOption()
        #expect(viewModel.canSubmit == false)
    }

    @Test("종료가 시작보다 빠름 → 불가")
    func endBeforeStartBlocksSubmit() {
        let viewModel = makeReadyViewModel()
        viewModel.endDate = viewModel.startDate.addingTimeInterval(-1)
        #expect(viewModel.canSubmit == false)
    }

    @Test("주차 커리큘럼 미선택 → 불가")
    func missingWeeklyOptionBlocksSubmit() {
        let viewModel = makeReadyViewModel()
        viewModel.selectedWeeklyOption = nil
        #expect(viewModel.canSubmit == false)
    }

    @Test("출석 정책 검증 에러 존재 → 불가")
    func attendancePolicyErrorBlocksSubmit() {
        let viewModel = makeReadyViewModel()
        // 출석 시작 ≥ 출석 인정 마감 → 단조 증가 위반
        viewModel.attendanceOnTimeEndAt = viewModel.attendanceCheckInStartAt
        viewModel.attendanceTimesChanged()
        #expect(viewModel.attendancePolicyError != nil)
        #expect(viewModel.canSubmit == false)
    }
}

// MARK: - 출석 정책 검증

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 출석 정책 검증 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelPolicyValidationTests {

    @Test("출석 시작 ≥ 출석 인정 마감 → checkInVsOnTime 에러")
    func checkInNotBeforeOnTimeFails() {
        let viewModel = makeViewModel()
        viewModel.startDate = fixedNow
        viewModel.attendanceCheckInStartAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceOnTimeEndAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceLateEndAt = fixedNow.addingTimeInterval(1_200)
        viewModel.attendanceTimesChanged()
        #expect(viewModel.attendancePolicyError == .invalidOrder(.checkInVsOnTime))
    }

    @Test("출석 인정 마감 ≥ 지각 인정 마감 → onTimeVsLate 에러")
    func onTimeNotBeforeLateFails() {
        let viewModel = makeViewModel()
        viewModel.startDate = fixedNow
        viewModel.attendanceCheckInStartAt = fixedNow.addingTimeInterval(-600)
        viewModel.attendanceOnTimeEndAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceLateEndAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceTimesChanged()
        #expect(viewModel.attendancePolicyError == .invalidOrder(.onTimeVsLate))
    }

    @Test("출석 시작 ≥ 일정 시작 → checkInAfterScheduleStart 에러")
    func checkInNotBeforeScheduleStartFails() {
        let viewModel = makeViewModel()
        viewModel.startDate = fixedNow
        // 단조 증가는 충족하되 출석 시작이 일정 시작보다 빠르지 않은 경우
        viewModel.attendanceCheckInStartAt = fixedNow
        viewModel.attendanceOnTimeEndAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceLateEndAt = fixedNow.addingTimeInterval(1_200)
        viewModel.attendanceTimesChanged()
        #expect(viewModel.attendancePolicyError == .checkInAfterScheduleStart)
    }

    @Test("단조 증가 + 일정 시작 이전 → 에러 없음")
    func validPolicyHasNoError() {
        let viewModel = makeViewModel()
        viewModel.startDate = fixedNow
        viewModel.attendanceCheckInStartAt = fixedNow.addingTimeInterval(-600)
        viewModel.attendanceOnTimeEndAt = fixedNow.addingTimeInterval(600)
        viewModel.attendanceLateEndAt = fixedNow.addingTimeInterval(1_200)
        viewModel.attendanceTimesChanged()
        #expect(viewModel.attendancePolicyError == nil)
    }
}

// MARK: - 출석 정책 prefill

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 출석 정책 prefill (도메인 규칙)")
struct StudyScheduleRegistrationViewModelPrefillTests {

    @Test("미수정 상태 → 일정 시작 기준 임계값으로 자동 채움")
    func prefillsRelativeToStartDate() {
        let viewModel = makeViewModel()
        viewModel.startDate = fixedNow
        viewModel.prefillAttendancePolicyIfNeeded()

        let onTime = TimeInterval(AttendancePolicy.onTimeThresholdMinutes * 60)
        let late = TimeInterval(AttendancePolicy.lateThresholdMinutes * 60)
        #expect(viewModel.attendanceCheckInStartAt == fixedNow.addingTimeInterval(-onTime))
        #expect(viewModel.attendanceOnTimeEndAt == fixedNow.addingTimeInterval(onTime))
        #expect(viewModel.attendanceLateEndAt == fixedNow.addingTimeInterval(late))
    }

    @Test("사용자가 시각을 직접 수정한 뒤 → prefill 이 덮어쓰지 않음")
    func prefillSkipsAfterUserEdit() {
        let viewModel = makeViewModel()
        let manualCheckIn = fixedNow.addingTimeInterval(-30)
        viewModel.attendanceCheckInStartAt = manualCheckIn
        viewModel.attendanceOnTimeEndAt = fixedNow.addingTimeInterval(60)
        viewModel.attendanceLateEndAt = fixedNow.addingTimeInterval(120)
        viewModel.attendanceTimesChanged()  // dirty 표시

        viewModel.startDate = fixedNow.addingTimeInterval(10_000)
        viewModel.prefillAttendancePolicyIfNeeded()

        #expect(viewModel.attendanceCheckInStartAt == manualCheckIn)
    }
}

// MARK: - 대면/비대면 토글

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 대면/비대면 토글 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelToggleTests {

    @Test("비대면 전환 → isOnline true + 이름·주소·좌표를 함께 비운다")
    func switchingToOnlineClearsPlace() {
        let viewModel = makeViewModel()
        viewModel.placeSelectionChanged(
            name: "한성대 상상관",
            address: "서울 성북구 삼선교로16길 116",
            coordinate: Coordinate(latitude: 37.5, longitude: 127.0)
        )

        viewModel.inPersonModeToggleChanged(to: false)

        #expect(viewModel.isOnline == true)
        #expect(viewModel.placeName.isEmpty)
        #expect(viewModel.placeAddress.isEmpty)
        #expect(viewModel.placeCoordinate == nil)
    }

    @Test("대면 전환 → isOnline false + 장소 보존")
    func switchingToInPersonKeepsPlace() {
        let viewModel = makeViewModel()
        viewModel.placeName = "한성대 상상관"
        viewModel.inPersonModeToggleChanged(to: true)
        #expect(viewModel.isOnline == false)
        #expect(viewModel.placeName == "한성대 상상관")
    }
}

// MARK: - 장소 선택 반영

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 장소 선택 반영 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelPlaceSelectionTests {

    @Test("장소 선택 → 이름·주소·좌표를 모두 반영한다")
    func selectingPlaceStoresAllFields() {
        let viewModel = makeViewModel()

        viewModel.placeSelectionChanged(
            name: "한성대 상상관",
            address: "서울 성북구 삼선교로16길 116",
            coordinate: Coordinate(latitude: 37.582, longitude: 127.010)
        )

        #expect(viewModel.placeName == "한성대 상상관")
        #expect(viewModel.placeAddress == "서울 성북구 삼선교로16길 116")
        #expect(viewModel.placeCoordinate == Coordinate(latitude: 37.582, longitude: 127.010))
    }

    @Test(
        "이름이 공백/개행뿐 → 선택 해제로 보고 좌표까지 비운다",
        arguments: ["", "   ", "\n", " \n "]
    )
    func selectingBlankNameClearsCoordinate(name: String) {
        let viewModel = makeViewModel()
        viewModel.placeSelectionChanged(
            name: "한성대 상상관",
            address: "서울 성북구 삼선교로16길 116",
            coordinate: Coordinate(latitude: 37.582, longitude: 127.010)
        )

        viewModel.placeSelectionChanged(
            name: name,
            address: "",
            coordinate: Coordinate(latitude: 0, longitude: 0)
        )

        #expect(viewModel.placeName.isEmpty)
        #expect(viewModel.placeAddress.isEmpty)
        #expect(viewModel.placeCoordinate == nil)
    }
}

// MARK: - 로딩 취소

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 로딩 취소 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelCancellationTests {

    @Test("주차 옵션 조회 취소 → 실패로 전이하지 않고 직전 결과를 유지한다")
    func cancelledWeeklyOptionsKeepsPreviousState() async {
        let repository = MockStudyScheduleRepository()
        let option = makeOption()
        repository.weeklyOptionsResult = .success([option])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadWeeklyOptions()

        repository.weeklyOptionsResult = .failure(CancellationError())
        await viewModel.loadWeeklyOptions()

        #expect(viewModel.weeklyOptionsState == .loaded([option]))
    }

    @Test("참여자 조회 취소 → 실패로 전이하지 않고 직전 결과를 유지한다")
    func cancelledParticipantsKeepsPreviousState() async {
        let useCase = MockFetchStudyMembersUseCase()
        let member = makeMember(memberID: "M-1")
        useCase.result = .success([member])
        let viewModel = makeViewModel(membersUseCase: useCase)
        await viewModel.loadParticipantMembers()

        useCase.result = .failure(CancellationError())
        await viewModel.loadParticipantMembers()

        #expect(viewModel.participantsState == .loaded([member]))
    }

    @Test("네트워크 요청 취소(URLError.cancelled)도 같은 취소로 다룬다")
    func cancelledURLErrorKeepsPreviousState() async {
        let repository = MockStudyScheduleRepository()
        let option = makeOption()
        repository.weeklyOptionsResult = .success([option])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadWeeklyOptions()

        repository.weeklyOptionsResult = .failure(URLError(.cancelled))
        await viewModel.loadWeeklyOptions()

        #expect(viewModel.weeklyOptionsState == .loaded([option]))
    }
}

// MARK: - 참여자 로딩

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 참여자 로딩 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelParticipantsTests {

    @Test("성공 + 본인 ID 일치 → 본인 제외하고 loaded")
    func loadsParticipantsExcludingSelf() async {
        let useCase = MockFetchStudyMembersUseCase()
        useCase.result = .success([
            makeMember(memberID: "M-1"),
            makeMember(memberID: "M-2"),
            makeMember(memberID: "M-self"),
        ])
        let viewModel = makeViewModel(membersUseCase: useCase, currentMemberId: "M-self")

        await viewModel.loadParticipantMembers()

        #expect(viewModel.participantMembers.map(\.memberID) == ["M-1", "M-2"])
        #expect(viewModel.participantsState.value?.map(\.memberID) == ["M-1", "M-2"])
        #expect(useCase.lastGroupId == "1")
    }

    @Test("본인 ID 없음 → 전체 멤버 유지")
    func loadsAllParticipantsWithoutSelfId() async {
        let useCase = MockFetchStudyMembersUseCase()
        useCase.result = .success([
            makeMember(memberID: "M-1"),
            makeMember(memberID: "M-2"),
        ])
        let viewModel = makeViewModel(membersUseCase: useCase, currentMemberId: nil)

        await viewModel.loadParticipantMembers()

        #expect(viewModel.participantMembers.map(\.memberID) == ["M-1", "M-2"])
    }

    @Test("DomainError → failed(.domain) 인라인 상태")
    func participantsDomainErrorMapsToFailed() async {
        let useCase = MockFetchStudyMembersUseCase()
        useCase.result = .failure(DomainError.custom(message: "참여자 조회 실패"))
        let viewModel = makeViewModel(membersUseCase: useCase)

        await viewModel.loadParticipantMembers()

        #expect(viewModel.participantsState == .failed(.domain(.custom(message: "참여자 조회 실패"))))
    }

    @Test("기타 에러 → failed 상태 (크래시 없이 인라인 처리)")
    func participantsUnknownErrorMapsToFailed() async {
        let useCase = MockFetchStudyMembersUseCase()
        useCase.result = .failure(DummyError())
        let viewModel = makeViewModel(membersUseCase: useCase)

        await viewModel.loadParticipantMembers()

        #expect(viewModel.participantsState.error != nil)
        #expect(viewModel.participantMembers.isEmpty)
    }
}

// MARK: - 주차 옵션 로딩

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 주차 옵션 로딩 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelWeeklyOptionsTests {

    @Test("성공 + 미선택 → loaded + 첫 옵션 자동 선택")
    func loadsAndAutoSelectsFirst() async {
        let repository = MockStudyScheduleRepository()
        let first = makeOption(id: "W-1", weekNo: "1", title: "OT")
        repository.weeklyOptionsResult = .success([
            first,
            makeOption(id: "W-2", weekNo: "2", title: "Git"),
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadWeeklyOptions()

        #expect(viewModel.weeklyOptionsState.value?.count == 2)
        #expect(viewModel.selectedWeeklyOption == first)
    }

    @Test("성공 + 이미 선택됨 → 자동 선택이 덮어쓰지 않음")
    func keepsExistingSelection() async {
        let repository = MockStudyScheduleRepository()
        repository.weeklyOptionsResult = .success([
            makeOption(id: "W-1", weekNo: "1", title: "OT"),
            makeOption(id: "W-2", weekNo: "2", title: "Git"),
        ])
        let viewModel = makeViewModel(repository: repository)
        let preset = makeOption(id: "W-2", weekNo: "2", title: "Git")
        viewModel.selectedWeeklyOption = preset

        await viewModel.loadWeeklyOptions()

        #expect(viewModel.selectedWeeklyOption == preset)
    }

    @Test("빈 목록 → loaded([]) + 선택 없음")
    func emptyOptionsLeaveSelectionNil() async {
        let repository = MockStudyScheduleRepository()
        repository.weeklyOptionsResult = .success([])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadWeeklyOptions()

        #expect(viewModel.weeklyOptionsState.value?.isEmpty == true)
        #expect(viewModel.selectedWeeklyOption == nil)
    }

    @Test("DomainError → failed(.domain) 인라인 상태")
    func weeklyOptionsDomainErrorMapsToFailed() async {
        let repository = MockStudyScheduleRepository()
        repository.weeklyOptionsResult = .failure(DomainError.custom(message: "주차 조회 실패"))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadWeeklyOptions()

        #expect(viewModel.weeklyOptionsState == .failed(.domain(.custom(message: "주차 조회 실패"))))
    }
}

// MARK: - 일정 등록 (2단계)

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 일정 등록 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelSubmitTests {

    @Test("필수 입력 미충족 → 서버 호출 없이 false")
    func submitSkipsWhenNotSubmittable() async {
        let register = MockRegisterStudyScheduleUseCase()
        let viewModel = makeViewModel(registerUseCase: register)
        // 주차 미선택 상태라 canSubmit == false
        #expect(viewModel.canSubmit == false)

        let result = await viewModel.submitSchedule()

        #expect(result == false)
        #expect(register.createdRequests.isEmpty)
    }

    @Test("생성 → 연결 모두 성공 → true")
    func submitSucceedsWhenBothStepsSucceed() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.createResult = .success("SCH-9")
        let viewModel = makeReadyViewModel(registerUseCase: register)

        let result = await viewModel.submitSchedule()

        #expect(result == true)
        #expect(register.linkCalls.count == 1)
        #expect(register.linkCalls.first?.scheduleId == "SCH-9")
        #expect(register.linkCalls.first?.studyGroupId == "1")
        #expect(register.linkCalls.first?.weeklyCurriculumId == "W-1")
        #expect(register.deletedScheduleIds.isEmpty)
    }

    @Test("1단계 생성 실패 → false + 연결 미시도")
    func submitFailsWhenCreateFails() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.createResult = .failure(DummyError())
        let viewModel = makeReadyViewModel(registerUseCase: register)

        let result = await viewModel.submitSchedule()

        #expect(result == false)
        #expect(register.linkCalls.isEmpty)
        #expect(register.deletedScheduleIds.isEmpty)
    }

    @Test("등록 진행 중 재호출 → 일정을 두 번 만들지 않는다")
    func concurrentSubmitIsGuarded() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.gateCreate = true
        let viewModel = makeReadyViewModel(registerUseCase: register)

        let first = Task { await viewModel.submitSchedule() }
        await drainUntil { register.createdRequests.count == 1 }

        let duplicate = await viewModel.submitSchedule()

        #expect(duplicate == false)
        #expect(register.createdRequests.count == 1)

        register.openCreateGate()
        #expect(await first.value == true)
    }

    @Test("2단계 연결 실패 → false + 재시도/취소 Alert 노출 (즉시 롤백하지 않음)")
    func submitPresentsAlertWhenLinkFails() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.linkResult = .failure(DummyError())
        let viewModel = makeReadyViewModel(registerUseCase: register)

        let result = await viewModel.submitSchedule()

        #expect(result == false)
        #expect(viewModel.alertPrompt != nil)
        #expect(register.deletedScheduleIds.isEmpty)
    }

    @Test("2단계 실패 후 재시도 성공 → 롤백 없이 연결 완료")
    func retryAfterLinkFailureLinksWithoutRollback() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.linkResult = .failure(DummyError())
        let viewModel = makeReadyViewModel(registerUseCase: register)
        _ = await viewModel.submitSchedule()

        register.linkResult = .success(())
        viewModel.alertPrompt?.positiveBtnAction?()
        await drainUntil { register.linkCalls.count == 2 }

        #expect(register.linkCalls.count == 2)
        #expect(register.deletedScheduleIds.isEmpty)
    }

    @Test("2단계 실패 후 취소 → 생성된 일정을 베스트 에포트로 삭제")
    func cancelAfterLinkFailureRollsBackSchedule() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.createResult = .success("SCH-9")
        register.linkResult = .failure(DummyError())
        let viewModel = makeReadyViewModel(registerUseCase: register)
        _ = await viewModel.submitSchedule()

        viewModel.alertPrompt?.negativeBtnAction?()
        await drainUntil { register.deletedScheduleIds.isEmpty == false }

        #expect(register.deletedScheduleIds == ["SCH-9"])
    }

    @Test("롤백 삭제 실패 → 예외를 삼키고 화면 흐름을 막지 않는다")
    func rollbackFailureIsSwallowed() async {
        let register = MockRegisterStudyScheduleUseCase()
        register.linkResult = .failure(DummyError())
        register.deleteResult = .failure(DummyError())
        let viewModel = makeReadyViewModel(registerUseCase: register)
        _ = await viewModel.submitSchedule()

        viewModel.alertPrompt?.negativeBtnAction?()
        await drainUntil { register.deletedScheduleIds.isEmpty == false }

        #expect(register.deletedScheduleIds == ["SCH-1"])
    }
}

// MARK: - 일정 등록 페이로드

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 일정 생성 페이로드 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelPayloadTests {

    @Test("비대면 → 장소 없이 전송하고 스터디 태그를 붙인다")
    func onlineScheduleOmitsLocation() async throws {
        let register = MockRegisterStudyScheduleUseCase()
        let viewModel = makeReadyViewModel(registerUseCase: register)

        _ = await viewModel.submitSchedule()

        let request = try #require(register.createdRequests.first)
        #expect(request.location == nil)
        #expect(request.tags == ["STUDY"])
    }

    @Test("대면 → 선택한 좌표와 장소명을 실어 보낸다")
    func inPersonScheduleSendsSelectedPlace() async throws {
        let register = MockRegisterStudyScheduleUseCase()
        let viewModel = makeReadyViewModel(registerUseCase: register)
        viewModel.isOnline = false
        viewModel.placeName = "  한성대 상상관  "
        viewModel.placeCoordinate = Coordinate(latitude: 37.582, longitude: 127.010)

        _ = await viewModel.submitSchedule()

        let location = try #require(register.createdRequests.first?.location)
        #expect(location.locationName == "한성대 상상관")
        #expect(location.latitude == 37.582)
        #expect(location.longitude == 127.010)
    }

    @Test("본인을 뺀 참여자 목록과 출석 정책 세 시각을 그대로 전송한다")
    func payloadCarriesParticipantsAndPolicy() async throws {
        let membersUseCase = MockFetchStudyMembersUseCase()
        membersUseCase.result = .success([
            makeMember(memberID: "M-self"),
            makeMember(memberID: "M-1"),
            makeMember(memberID: "M-2"),
        ])
        let register = MockRegisterStudyScheduleUseCase()
        let viewModel = makeViewModel(
            membersUseCase: membersUseCase,
            registerUseCase: register,
            currentMemberId: "M-self"
        )
        viewModel.isOnline = true
        viewModel.selectedWeeklyOption = makeOption()
        await viewModel.loadParticipantMembers()

        _ = await viewModel.submitSchedule()

        let request = try #require(register.createdRequests.first)
        #expect(request.participantMemberIds == ["M-1", "M-2"])
        #expect(request.attendancePolicy?.checkInStartAt == viewModel.attendanceCheckInStartAt)
        #expect(request.attendancePolicy?.onTimeEndAt == viewModel.attendanceOnTimeEndAt)
        #expect(request.attendancePolicy?.lateEndAt == viewModel.attendanceLateEndAt)
    }
}

#endif
