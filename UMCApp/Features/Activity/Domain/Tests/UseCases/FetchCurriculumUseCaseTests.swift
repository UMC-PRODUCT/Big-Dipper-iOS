//
//  FetchCurriculumUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

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

private func makeUseCase(
    repository: MockStudyRepository = MockStudyRepository()
) -> FetchCurriculumUseCase {
    FetchCurriculumUseCase(repository: repository)
}

// MARK: - Mocks

#if DEBUG

private enum MockStudyRepositoryError: Error {
    case fetchFailed
}

/// `StudyRepositoryProtocol` 의 테스트 전용 Mock.
///
/// 본 UseCase 가 계약하는 `fetchCurriculumProgress()` 만 제어 가능한 stub 으로 노출하고,
/// 나머지 메서드는 계약 밖이므로 호출 시 `fatalError` 로 즉시 실패합니다.
private final class MockStudyRepository: @unchecked Sendable, StudyRepositoryProtocol {

    // MARK: 커리큘럼 stub 제어

    var fetchCurriculumProgressResult: CurriculumProgressModel = makeProgress()
    var fetchCurriculumProgressError: Error?
    private(set) var fetchCurriculumProgressCallCount = 0

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        fetchCurriculumProgressCallCount += 1
        if let error = fetchCurriculumProgressError {
            throw error
        }
        return fetchCurriculumProgressResult
    }

    // MARK: 계약 밖 메서드 (호출 시 실패 — 본 UseCase 는 사용하지 않음)

    func fetchMissions() async throws -> [MissionCardModel] {
        fatalError("fetchMissions 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        fatalError("fetchWeeklyCurriculumOptions 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        fatalError("fetchStudyGroupDetails 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        fatalError("fetchStudyGroupDetailsPage 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        fatalError("fetchStudyGroupDetail 은 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: Int?
    ) async throws -> String? {
        fatalError("resolveChallengerId 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        fatalError("createStudyGroup 은 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        fatalError("updateStudyGroup 은 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func deleteStudyGroup(groupId: String) async throws {
        fatalError("deleteStudyGroup 은 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("addStudyGroupMember 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("removeStudyGroupMember 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("addStudyGroupMentor 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("removeStudyGroupMentor 는 FetchCurriculumUseCase 계약 밖입니다.")
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        fatalError("linkStudyGroupSchedule 은 FetchCurriculumUseCase 계약 밖입니다.")
    }
}

#endif

// MARK: - 커리큘럼 진행률 조회

@Suite("FetchCurriculumUseCase — 커리큘럼 진행률 조회 (도메인 규칙)")
struct FetchCurriculumUseCaseTests {

    @Test("정상 — Repository.fetchCurriculumProgress 위임 + 결과 그대로 반환 + 1회 호출")
    func executeDelegatesToRepository() async throws {
        let repository = MockStudyRepository()
        let expected = makeProgress(
            partName: "Spring",
            curriculumTitle: "3주차 세션",
            completedCount: 5,
            totalCount: 10
        )
        repository.fetchCurriculumProgressResult = expected
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(repository.fetchCurriculumProgressCallCount == 1)
        // 변환 없는 패스스루 검증 — 도메인 의미 필드 단위 비교.
        // (`id` 는 로컬 생성 UUID 라 검증 대상에서 제외)
        #expect(result.partName == "Spring")
        #expect(result.curriculumTitle == "3주차 세션")
        #expect(result.completedCount == 5)
        #expect(result.totalCount == 10)
    }

    @Test("Repository 에러 → 변환 없이 그대로 전파")
    func executePropagatesRepositoryError() async {
        let repository = MockStudyRepository()
        repository.fetchCurriculumProgressError = MockStudyRepositoryError.fetchFailed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockStudyRepositoryError.fetchFailed) {
            _ = try await useCase.execute()
        }
    }
}
