//
//  ScheduleRegistrationViewModelTests.swift
//  HomePresentationTests
//
//  Created by euijjang97 on 8/9/26.
//

import CoreDI
import CoreDomain
import Foundation
import HomeDomain
import Testing
import UMCFoundation
@testable import HomePresentation

@MainActor
@Suite("ScheduleRegistrationViewModel — 출석 정책 검증")
struct ScheduleRegistrationAttendancePolicyTests {

    @Test(
        "세 시각의 순서와 일정 범위를 어기면 각각의 안내가 나온다",
        arguments: AttendancePolicyCase.all
    )
    func validatesAttendancePolicy(policyCase: AttendancePolicyCase) {
        let viewModel = makeViewModel()
        viewModel.isAttendanceRequired = true
        viewModel.attendanceCheckInStartAt = viewModel.startDate
            .addingTimeInterval(policyCase.checkInOffset)
        viewModel.attendanceOnTimeEndAt = viewModel.startDate
            .addingTimeInterval(policyCase.onTimeOffset)
        viewModel.attendanceLateEndAt = viewModel.startDate
            .addingTimeInterval(policyCase.lateOffset)

        viewModel.attendanceTimesChanged()

        #expect(viewModel.attendancePolicyErrorMessage == policyCase.expectedMessage)
    }
}

@MainActor
@Suite("ScheduleRegistrationViewModel — 참여자 결선")
struct ScheduleRegistrationParticipantTests {

    @Test("아무도 고르지 않아도 생성 요청에는 작성자 본인이 들어간다")
    func creationAlwaysIncludesAuthor() async {
        let recorder = RequestRecorder()
        let viewModel = makeViewModel(recorder: recorder)
        viewModel.title = "정기 세미나"

        await viewModel.submitSchedule()

        #expect(recorder.creation?.participantMemberIds == ["7"])
    }

    @Test("선택한 참여자에 작성자를 더해 중복 없이 보낸다")
    func creationMergesAuthorIntoSelection() async {
        let recorder = RequestRecorder()
        let viewModel = makeViewModel(recorder: recorder)
        viewModel.updateParticipants([challenger(memberId: "10"), challenger(memberId: "7")])

        await viewModel.submitSchedule()

        #expect(recorder.creation?.participantMemberIds == ["10", "7"])
    }

    @Test("초대 인원이 상한을 넘으면 안내가 뜨고 저장이 막힌다")
    func participantOverflowBlocksSubmit() async {
        let viewModel = makeViewModel(capabilities: makeCapabilities(maxParticipantCount: "2"))
        fillRequiredFields(of: viewModel)
        viewModel.updateParticipants([challenger(memberId: "10"), challenger(memberId: "11")])

        await viewModel.loadCapabilities()

        #expect(viewModel.selectedParticipantCount == 3)
        #expect(viewModel.participantOverflowMessage != nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test("상한 이내면 안내 없이 저장이 열린다")
    func participantWithinLimitAllowsSubmit() async {
        let viewModel = makeViewModel(capabilities: makeCapabilities(maxParticipantCount: "3"))
        fillRequiredFields(of: viewModel)
        viewModel.updateParticipants([challenger(memberId: "10"), challenger(memberId: "11")])

        await viewModel.loadCapabilities()

        #expect(viewModel.participantOverflowMessage == nil)
        #expect(viewModel.canSubmit)
    }
}

@MainActor
@Suite("ScheduleRegistrationViewModel — 수정 모드 변경 감지와 서버 거부")
struct ScheduleRegistrationEditModeTests {

    @Test("참여자만 바뀌어도 변경 감지에 걸린다")
    func participantChangeMarksEditDirty() {
        let viewModel = makeViewModel()
        viewModel.applyPrefill(from: makeDetail(participantMemberIds: ["7", "10"]))
        #expect(viewModel.hasChangesInEditMode == false)

        viewModel.updateParticipants(viewModel.participants + [challenger(memberId: "11")])

        #expect(viewModel.hasChangesInEditMode)
    }

    @Test("바뀌지 않은 필드는 PATCH 요청에서 빠진다")
    func unchangedFieldsAreOmittedFromUpdate() async {
        let recorder = RequestRecorder()
        let viewModel = makeViewModel(recorder: recorder)
        viewModel.applyPrefill(from: makeDetail(participantMemberIds: ["7", "10"]))
        viewModel.title = "제목만 수정"

        await viewModel.updateSchedule()

        #expect(recorder.update?.name == "제목만 수정")
        #expect(recorder.update?.participantMemberIds == nil)
        #expect(recorder.update?.isOnline == nil)
        #expect(recorder.update?.isAttendanceRequired == nil)
    }

    @Test("참여자가 바뀌면 PATCH 에 작성자 포함 목록이 실린다")
    func changedParticipantsAreSentOnUpdate() async {
        let recorder = RequestRecorder()
        let viewModel = makeViewModel(recorder: recorder)
        viewModel.applyPrefill(from: makeDetail(participantMemberIds: ["7"]))
        viewModel.updateParticipants(viewModel.participants + [challenger(memberId: "10")])

        await viewModel.updateSchedule()

        #expect(recorder.update?.participantMemberIds == ["10", "7"])
    }

    @Test("서버가 SCHEDULE-0028 로 거부하면 인라인 메시지로 알린다")
    func startedScheduleRejectionShowsInlineMessage() async {
        let viewModel = makeViewModel(
            updateError: RepositoryError.serverError(code: "SCHEDULE-0028", message: "이미 시작됨")
        )
        viewModel.applyPrefill(from: makeDetail())
        viewModel.title = "제목만 수정"

        await viewModel.updateSchedule()

        #expect(viewModel.inlineErrorMessage == "이미 시작된 일정은 수정할 수 없습니다.")
        #expect(viewModel.submitState.isLoading == false)
    }
}

// MARK: - AttendancePolicyCase

/// 출석 정책 검증 입력. 오프셋은 모두 일정 시작 시각 기준이며 일정 종료는 시작 + 3600 이다.
///
/// `@Test(arguments:)` 파라미터 타입이라 테스트 메서드와 같은 접근 수준이어야 한다.
struct AttendancePolicyCase: Sendable {

    let checkInOffset: TimeInterval
    let onTimeOffset: TimeInterval
    let lateOffset: TimeInterval
    let expectedMessage: String?

    static let all: [AttendancePolicyCase] = [
        AttendancePolicyCase(
            checkInOffset: 0,
            onTimeOffset: -60,
            lateOffset: 600,
            expectedMessage: "출석 시작은 출석 인정 마감보다 빨라야 합니다."
        ),
        AttendancePolicyCase(
            checkInOffset: -600,
            onTimeOffset: 0,
            lateOffset: -300,
            expectedMessage: "출석 인정 마감은 지각 인정 마감보다 빨라야 합니다."
        ),
        AttendancePolicyCase(
            checkInOffset: 0,
            onTimeOffset: 60,
            lateOffset: 120,
            expectedMessage: "출석 시작은 일정 시작보다 빨라야 합니다."
        ),
        AttendancePolicyCase(
            checkInOffset: -600,
            onTimeOffset: 0,
            lateOffset: 3_660,
            expectedMessage: "지각 인정 마감은 일정 종료 시각을 넘을 수 없습니다."
        ),
        AttendancePolicyCase(
            checkInOffset: -600,
            onTimeOffset: 0,
            lateOffset: 600,
            expectedMessage: nil
        )
    ]
}

// MARK: - Helpers

@MainActor
private func makeViewModel(
    currentMemberId: String? = "7",
    capabilities: ScheduleCapabilities? = nil,
    updateError: Error? = nil,
    recorder: RequestRecorder? = nil
) -> ScheduleRegistrationViewModel {
    let container = DIContainer()
    container.register(GenerateScheduleUseCaseProtocol.self) {
        StubGenerateScheduleUseCase(recorder: recorder)
    }
    container.register(UpdateScheduleUseCaseProtocol.self) {
        StubUpdateScheduleUseCase(recorder: recorder, error: updateError)
    }
    container.register(ClassifyScheduleUseCaseProtocol.self) {
        StubClassifyScheduleUseCase()
    }
    container.register(FetchScheduleCapabilitiesUseCaseProtocol.self) {
        StubFetchScheduleCapabilitiesUseCase(capabilities: capabilities)
    }
    return ScheduleRegistrationViewModel(container: container, currentMemberId: currentMemberId)
}

/// `canSubmit` 이 참여자 상한 외의 이유로 막히지 않도록 필수 입력을 채운다.
@MainActor
private func fillRequiredFields(of viewModel: ScheduleRegistrationViewModel) {
    viewModel.title = "정기 세미나"
    viewModel.updateTagsFromUser([.study])
    viewModel.inPersonModeToggleChanged(to: false)
}

private func makeCapabilities(maxParticipantCount: String) -> ScheduleCapabilities {
    ScheduleCapabilities(
        canCreateSchedule: true,
        canCreateAttendanceRequiredSchedule: true,
        maxParticipantCount: maxParticipantCount
    )
}

private func challenger(memberId: String) -> ChallengerInfo {
    ChallengerInfo(
        memberId: memberId,
        gen: "11",
        name: "홍길동",
        nickname: "gildong",
        schoolName: "UMC대학교",
        profileImage: nil,
        part: .front(type: .ios)
    )
}

/// 아직 시작하지 않은 비대면 일정. 수정 모드 가드(SCHEDULE-0028 사전 차단)를 통과한다.
private func makeDetail(participantMemberIds: [String] = ["7"]) -> ScheduleDetailData {
    let startsAt = Date.now.addingTimeInterval(3_600)
    return ScheduleDetailData(
        scheduleId: "1",
        name: "정기 세미나",
        description: "",
        tags: ["STUDY"],
        startsAt: startsAt,
        endsAt: startsAt.addingTimeInterval(3_600),
        isParticipant: true,
        participants: participantMemberIds.map {
            ScheduleParticipant(
                memberId: $0,
                name: "홍길동",
                nickname: "gildong",
                profileImageUrl: "",
                schoolId: "1",
                schoolName: "UMC대학교"
            )
        },
        authorMemberId: "7",
        isOnline: true
    )
}

// MARK: - Stubs

/// 서버로 나간 요청을 붙잡아 두는 기록기.
@MainActor
private final class RequestRecorder {
    var creation: ScheduleCreationRequest?
    var update: ScheduleUpdateRequest?
}

private struct StubGenerateScheduleUseCase: GenerateScheduleUseCaseProtocol {

    let recorder: RequestRecorder?

    @discardableResult
    func execute(request: ScheduleCreationRequest) async throws -> String {
        let capturedRecorder = recorder
        await MainActor.run { capturedRecorder?.creation = request }
        return "1"
    }
}

private struct StubUpdateScheduleUseCase: UpdateScheduleUseCaseProtocol {

    let recorder: RequestRecorder?
    let error: Error?

    func execute(scheduleId: String, request: ScheduleUpdateRequest) async throws {
        let capturedRecorder = recorder
        await MainActor.run { capturedRecorder?.update = request }
        if let error { throw error }
    }
}

private struct StubClassifyScheduleUseCase: ClassifyScheduleUseCaseProtocol {
    func execute(title: String) async -> ScheduleIconCategory { .study }
}

private struct StubFetchScheduleCapabilitiesUseCase: FetchScheduleCapabilitiesUseCaseProtocol {

    let capabilities: ScheduleCapabilities?

    func execute() async throws -> ScheduleCapabilities {
        guard let capabilities else {
            throw RepositoryError.invalidResponse(detail: "권한 stub 미설정")
        }
        return capabilities
    }
}
