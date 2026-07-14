//
//  StudyScheduleRegistrationViewModelTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import Testing
import ActivityDomain
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
    currentMemberId: String? = nil
) -> StudyScheduleRegistrationViewModel {
    StudyScheduleRegistrationViewModel(
        studyName: studyName,
        studyGroupId: studyGroupId,
        studyMembersUseCase: membersUseCase,
        studyRepository: repository,
        currentMemberId: currentMemberId
    )
}

/// `canSubmit == true` 를 만족하는 기본 뷰 모델 (비대면 + 주차 선택 완료)
@MainActor
private func makeReadyViewModel() -> StudyScheduleRegistrationViewModel {
    let viewModel = makeViewModel()
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

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        fatalError("fetchCurriculumProgress 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
    }

    func fetchMissions() async throws -> [MissionCardModel] {
        fatalError("fetchMissions 는 StudyScheduleRegistrationViewModel 계약 밖입니다.")
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
        fatalError("linkStudyGroupSchedule 은 StudyScheduleRegistrationViewModel 계약 밖입니다.")
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
        #expect(viewModel.canSubmit == false)
    }

    @Test("대면 + 장소 입력 → 가능")
    func inPersonWithPlaceAllowsSubmit() {
        let viewModel = makeReadyViewModel()
        viewModel.isOnline = false
        viewModel.placeName = "한성대 상상관"
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

    @Test("비대면 전환 → isOnline true + 장소 초기화")
    func switchingToOnlineClearsPlace() {
        let viewModel = makeViewModel()
        viewModel.placeName = "한성대 상상관"
        viewModel.inPersonModeToggleChanged(to: false)
        #expect(viewModel.isOnline == true)
        #expect(viewModel.placeName.isEmpty)
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

// MARK: - 일정 등록 스텁

@MainActor
@Suite("StudyScheduleRegistrationViewModel — 일정 등록 스텁 (도메인 규칙)")
struct StudyScheduleRegistrationViewModelSubmitStubTests {

    @Test("필수 입력 충족이어도 false — Schedule 모듈 이식 전 스텁 계약")
    func submitReturnsFalseWhileStubbed() async {
        let viewModel = makeReadyViewModel()
        #expect(viewModel.canSubmit == true)

        let result = await viewModel.submitSchedule()

        #expect(result == false)
    }
}

#endif
