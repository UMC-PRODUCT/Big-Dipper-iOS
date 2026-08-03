//
//  FetchCurriculumOverviewUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 7/29/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// 이 테스트 파일은 전부 #if DEBUG 전용 Mock 에 의존하므로 본문 전체를 가드한다.
#if DEBUG

// MARK: - Helpers

private func makeProgress(
    partName: String = "iOS",
    curriculumTitle: String = "1주차 OT",
    completedCount: Int = 2,
    totalCount: Int = 8
) -> CurriculumProgressModel {
    CurriculumProgressModel(
        partName: partName,
        curriculumTitle: curriculumTitle,
        completedCount: completedCount,
        totalCount: totalCount
    )
}

/// 검증 대상은 `week`/`status` 뿐이며, `platform`/`title`/`missionTitle` 은
/// 상태 검증과 무관한 고정 filler 값이다.
private func makeMission(
    week: Int = 1,
    status: MissionStatus = .inProgress
) -> MissionCardModel {
    MissionCardModel(
        week: week,
        platform: "iOS",
        title: "\(week)주차 OT",
        missionTitle: "링크를 제출하세요",
        status: status
    )
}

private func makeUseCase(
    repository: MockStudyRepository = MockStudyRepository()
) -> FetchCurriculumOverviewUseCase {
    FetchCurriculumOverviewUseCase(repository: repository)
}

// MARK: - Mocks

private enum MockStudyRepositoryError: Error {
    case fetchFailed
}

/// `StudyRepositoryProtocol` 의 테스트 전용 Mock.
///
/// 본 UseCase 가 계약하는 `fetchCurriculumOverview()` 만 제어 가능한 stub 으로 노출하고,
/// 나머지 메서드는 계약 밖이므로 호출 시 `fatalError` 로 즉시 실패합니다.
private final class MockStudyRepository: @unchecked Sendable, StudyRepositoryProtocol {

    // MARK: 커리큘럼 개요 stub 제어

    var fetchCurriculumOverviewResult = CurriculumOverview(
        progress: makeProgress(),
        missions: [makeMission()]
    )
    var fetchCurriculumOverviewError: Error?
    private(set) var fetchCurriculumOverviewCallCount = 0

    func fetchCurriculumOverview() async throws -> CurriculumOverview {
        fetchCurriculumOverviewCallCount += 1
        if let error = fetchCurriculumOverviewError {
            throw error
        }
        return fetchCurriculumOverviewResult
    }

    // MARK: 계약 밖 메서드 (호출 시 실패 — 본 UseCase 는 사용하지 않음)

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        fatalError("fetchWeeklyCurriculumOptions 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        fatalError("fetchStudyGroupDetails 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        fatalError("fetchStudyGroupDetailsPage 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        fatalError("fetchStudyGroupDetail 은 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        fatalError("resolveChallengerId 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        fatalError("fetchStudyGroupNames 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        fatalError("fetchStudyMemberSubmissions 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        fatalError("createStudyGroup 은 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        fatalError("updateStudyGroup 은 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func deleteStudyGroup(groupId: String) async throws {
        fatalError("deleteStudyGroup 은 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("addStudyGroupMember 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("removeStudyGroupMember 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("addStudyGroupMentor 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("removeStudyGroupMentor 는 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        fatalError("linkStudyGroupSchedule 은 FetchCurriculumOverviewUseCase 계약 밖입니다.")
    }
}

// MARK: - 커리큘럼 개요 조회

@Suite("FetchCurriculumOverviewUseCase — 커리큘럼 개요 조회 (도메인 규칙)")
struct FetchCurriculumOverviewUseCaseTests {

    @Test("정상 — Repository.fetchCurriculumOverview 위임 + 결과 그대로 반환 + 1회 호출")
    func executeDelegatesToRepository() async throws {
        let repository = MockStudyRepository()
        let expectedProgress = makeProgress(
            partName: "Spring",
            curriculumTitle: "3주차 세션",
            completedCount: 5,
            totalCount: 10
        )
        repository.fetchCurriculumOverviewResult = CurriculumOverview(
            progress: expectedProgress,
            missions: [
                makeMission(week: 1, status: .pass),
                makeMission(week: 2, status: .inProgress)
            ]
        )
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(repository.fetchCurriculumOverviewCallCount == 1)
        #expect(result.progress == expectedProgress)
        // 변환 없는 패스스루 검증 — 도메인 의미 필드 단위 비교.
        // (`id` 는 로컬 생성 UUID 라 검증 대상에서 제외)
        #expect(result.missions.map(\.week) == [1, 2])
        #expect(result.missions.map(\.status) == [.pass, .inProgress])
    }

    @Test("Repository 에러 → 변환 없이 그대로 전파")
    func executePropagatesRepositoryError() async {
        let repository = MockStudyRepository()
        repository.fetchCurriculumOverviewError = MockStudyRepositoryError.fetchFailed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockStudyRepositoryError.fetchFailed) {
            _ = try await useCase.execute()
        }
    }
}

#endif
