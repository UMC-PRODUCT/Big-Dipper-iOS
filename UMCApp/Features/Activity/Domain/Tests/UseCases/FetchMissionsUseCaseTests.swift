//
//  FetchMissionsUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 7/15/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// 이 테스트 파일은 전부 #if DEBUG 전용 Mock 에 의존하므로 본문 전체를 가드한다.
#if DEBUG

// MARK: - Helpers

private func makeMission(
    week: Int = 1,
    platform: String = "iOS",
    title: String = "1주차 OT",
    missionTitle: String = "링크를 제출하세요",
    status: MissionStatus = .inProgress
) -> MissionCardModel {
    MissionCardModel(
        week: week,
        platform: platform,
        title: title,
        missionTitle: missionTitle,
        status: status
    )
}

private func makeUseCase(
    repository: MockStudyRepository = MockStudyRepository()
) -> FetchMissionsUseCase {
    FetchMissionsUseCase(repository: repository)
}

// MARK: - Mocks

private enum MockStudyRepositoryError: Error {
    case fetchFailed
}

/// `StudyRepositoryProtocol` 의 테스트 전용 Mock.
///
/// 본 UseCase 가 계약하는 `fetchMissions()` 만 제어 가능한 stub 으로 노출하고,
/// 나머지 메서드는 계약 밖이므로 호출 시 `fatalError` 로 즉시 실패합니다.
private final class MockStudyRepository: @unchecked Sendable, StudyRepositoryProtocol {

    // MARK: 미션 stub 제어

    var fetchMissionsResult: [MissionCardModel] = [makeMission()]
    var fetchMissionsError: Error?
    private(set) var fetchMissionsCallCount = 0

    func fetchMissions() async throws -> [MissionCardModel] {
        fetchMissionsCallCount += 1
        if let error = fetchMissionsError {
            throw error
        }
        return fetchMissionsResult
    }

    // MARK: 계약 밖 메서드 (호출 시 실패 — 본 UseCase 는 사용하지 않음)

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        fatalError("fetchCurriculumProgress 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        fatalError("fetchWeeklyCurriculumOptions 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        fatalError("fetchStudyGroupDetails 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        fatalError("fetchStudyGroupDetailsPage 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        fatalError("fetchStudyGroupDetail 은 FetchMissionsUseCase 계약 밖입니다.")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        fatalError("resolveChallengerId 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        fatalError("createStudyGroup 은 FetchMissionsUseCase 계약 밖입니다.")
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        fatalError("updateStudyGroup 은 FetchMissionsUseCase 계약 밖입니다.")
    }

    func deleteStudyGroup(groupId: String) async throws {
        fatalError("deleteStudyGroup 은 FetchMissionsUseCase 계약 밖입니다.")
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("addStudyGroupMember 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        fatalError("removeStudyGroupMember 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("addStudyGroupMentor 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        fatalError("removeStudyGroupMentor 는 FetchMissionsUseCase 계약 밖입니다.")
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        fatalError("linkStudyGroupSchedule 은 FetchMissionsUseCase 계약 밖입니다.")
    }
}

// MARK: - 주차별 미션 조회

@Suite("FetchMissionsUseCase — 주차별 미션 조회 (도메인 규칙)")
struct FetchMissionsUseCaseTests {

    @Test("정상 — Repository.fetchMissions 위임 + 결과 그대로 반환 + 1회 호출")
    func executeDelegatesToRepository() async throws {
        let repository = MockStudyRepository()
        let expected = [
            makeMission(week: 1, status: .pass),
            makeMission(week: 2, status: .inProgress)
        ]
        repository.fetchMissionsResult = expected
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(repository.fetchMissionsCallCount == 1)
        // 변환 없는 패스스루 검증 — 도메인 의미 필드 단위 비교.
        // (`id` 는 로컬 생성 UUID 라 검증 대상에서 제외)
        #expect(result.map(\.week) == [1, 2])
        #expect(result.map(\.status) == [.pass, .inProgress])
    }

    @Test("Repository 에러 → 변환 없이 그대로 전파")
    func executePropagatesRepositoryError() async {
        let repository = MockStudyRepository()
        repository.fetchMissionsError = MockStudyRepositoryError.fetchFailed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockStudyRepositoryError.fetchFailed) {
            _ = try await useCase.execute()
        }
    }
}

#endif
