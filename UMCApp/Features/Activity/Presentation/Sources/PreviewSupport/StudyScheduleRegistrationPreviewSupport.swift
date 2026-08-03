//
//  StudyScheduleRegistrationPreviewSupport.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import Foundation
import HomeDomain
import UMCFoundation

// MARK: - Preview Stubs

/// 프리뷰 전용 멤버 조회 스텁 — 고정된 스터디원 목록을 돌려준다.
final class PreviewStudyScheduleMembersUseCase: FetchStudyMembersUseCaseProtocol {

    func fetchStudyGroupMembers(groupId: String) async throws -> [StudyGroupMember] {
        [
            StudyGroupMember(
                serverID: "1",
                memberID: "1",
                name: "김스터디",
                university: "한성대학교"
            ),
            StudyGroupMember(
                serverID: "2",
                memberID: "2",
                name: "이참여",
                university: "한성대학교"
            ),
        ]
    }
}

/// 프리뷰 전용 스터디 Repository 스텁.
///
/// 일정 등록 화면은 주차 커리큘럼 옵션만 조회하므로 그 메서드만 값을 돌려주고, 나머지는
/// 프리뷰에서 호출될 일이 없어 계약 밖으로 둔다.
final class PreviewStudyScheduleRepository: StudyRepositoryProtocol {

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        [
            WeeklyCurriculumOption(weeklyCurriculumId: "1", weekNo: "1", title: "OT"),
            WeeklyCurriculumOption(weeklyCurriculumId: "2", weekNo: "2", title: "Git & GitHub"),
        ]
    }

    func fetchCurriculumOverview() async throws -> CurriculumOverview {
        throw DomainError.custom(message: "프리뷰 계약 밖")
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] { [] }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        throw DomainError.custom(message: "프리뷰 계약 밖")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        throw DomainError.custom(message: "프리뷰 계약 밖")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        nil
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {}

    func updateStudyGroup(groupId: String, name: String) async throws {}

    func deleteStudyGroup(groupId: String) async throws {}

    func addStudyGroupMember(groupId: String, memberId: String) async throws {}

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {}

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {}

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {}

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {}
}

/// 프리뷰 전용 일정 등록 UseCase 스텁 — 서버 호출 없이 성공한 척한다.
final class PreviewRegisterStudyScheduleUseCase: RegisterStudyScheduleUseCaseProtocol {

    func createSchedule(_ request: ScheduleCreationRequest) async throws -> String { "1" }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {}

    func deleteSchedule(scheduleId: String) async throws {}
}

// MARK: - Preview Factory

/// 주차 옵션과 참여자가 채워지는 프리뷰용 일정 등록 ViewModel.
@MainActor
func previewStudyScheduleRegistrationViewModel() -> StudyScheduleRegistrationViewModel {
    StudyScheduleRegistrationViewModel(
        studyName: "iOS 스터디",
        studyGroupId: "1",
        studyMembersUseCase: PreviewStudyScheduleMembersUseCase(),
        studyRepository: PreviewStudyScheduleRepository(),
        registerScheduleUseCase: PreviewRegisterStudyScheduleUseCase(),
        errorHandler: ErrorHandler(),
        currentMemberId: nil
    )
}
#endif
