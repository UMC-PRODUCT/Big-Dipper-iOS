//
//  FetchStudyMembersUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

private func makeMember(
    serverID: String,
    name: String,
    role: StudyGroupMember.MemberRole = .member
) -> StudyGroupMember {
    StudyGroupMember(
        serverID: serverID,
        name: name,
        university: "한성대학교",
        role: role
    )
}

private func makeGroupInfo(
    serverID: String = "G-1",
    mentors: [StudyGroupMember],
    members: [StudyGroupMember]
) -> StudyGroupInfo {
    StudyGroupInfo(
        serverID: serverID,
        name: "iOS 스터디",
        part: .front(type: .ios), // 테스트 결과와 무관 — 임의 고정값
        createdDate: Date(timeIntervalSince1970: 1_000),
        mentors: mentors,
        members: members
    )
}

private func makeUseCase(
    repository: MockStudyRepository = MockStudyRepository()
) -> FetchStudyMembersUseCase {
    FetchStudyMembersUseCase(repository: repository)
}

// MARK: - Mocks

#if DEBUG

/// `fetchStudyGroupDetail` 만 컨트롤하는 포커스드 Mock.
/// 본 UseCase 가 호출하지 않는 나머지 계약 메서드는 호출 시 즉시 실패하도록 `unimplemented` 를 던집니다.
private final class MockStudyRepository: @unchecked Sendable, StudyRepositoryProtocol {

    enum MockError: Error {
        /// 본 UseCase 가 호출하면 안 되는 계약 메서드를 건드렸음을 알리는 표식
        case unimplemented
        /// 에러 전파 경로 검증용 — Repository 가 의도적으로 실패할 때 던지는 스텁 에러
        case stubbed
    }

    // MARK: 입출력 기록

    var fetchStudyGroupDetailResult: StudyGroupInfo = makeGroupInfo(mentors: [], members: [])
    var fetchStudyGroupDetailError: Error?
    private(set) var fetchStudyGroupDetailCalls: [String] = []

    // MARK: 본 UseCase 가 사용하는 메서드

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        fetchStudyGroupDetailCalls.append(groupId)
        if let fetchStudyGroupDetailError {
            throw fetchStudyGroupDetailError
        }
        return fetchStudyGroupDetailResult
    }

    // MARK: 본 UseCase 미사용 — 호출 시 unimplemented

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        throw MockError.unimplemented
    }

    func fetchMissions() async throws -> [MissionCardModel] {
        throw MockError.unimplemented
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        throw MockError.unimplemented
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        throw MockError.unimplemented
    }

    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        throw MockError.unimplemented
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: Int?
    ) async throws -> String? {
        throw MockError.unimplemented
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        throw MockError.unimplemented
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        throw MockError.unimplemented
    }

    func deleteStudyGroup(groupId: String) async throws {
        throw MockError.unimplemented
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        throw MockError.unimplemented
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        throw MockError.unimplemented
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        throw MockError.unimplemented
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        throw MockError.unimplemented
    }

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        throw MockError.unimplemented
    }
}

#endif

// MARK: - 멤버 조회

@Suite("FetchStudyMembersUseCase — 스터디 그룹 멤버 조회 (도메인 규칙)")
struct FetchStudyMembersUseCaseTests {

    @Test("멘토 + 스터디원 병합 — 멘토 우선 순서 유지 + groupId 위임")
    func mergesMentorsBeforeMembersAndDelegatesGroupId() async throws {
        let repository = MockStudyRepository()
        let mentor = makeMember(serverID: "M-1", name: "멘토", role: .leader)
        let memberA = makeMember(serverID: "C-1", name: "챌린저A")
        let memberB = makeMember(serverID: "C-2", name: "챌린저B")
        repository.fetchStudyGroupDetailResult = makeGroupInfo(
            mentors: [mentor],
            members: [memberA, memberB]
        )
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.fetchStudyGroupMembers(groupId: "G-7")

        #expect(result.map(\.serverID) == ["M-1", "C-1", "C-2"])
        #expect(repository.fetchStudyGroupDetailCalls == ["G-7"])
    }

    @Test(
        "멘토 없을 때 — 스터디원만 반환 (빈 그룹 포함)",
        arguments: [
            (members: [makeMember(serverID: "C-1", name: "챌린저A")], expected: ["C-1"]),
            (members: [], expected: [String]())
        ]
    )
    func returnsMembersOnlyWhenNoMentors(
        members: [StudyGroupMember],
        expected: [String]
    ) async throws {
        let repository = MockStudyRepository()
        repository.fetchStudyGroupDetailResult = makeGroupInfo(mentors: [], members: members)
        let useCase = makeUseCase(repository: repository)

        let result = try await useCase.fetchStudyGroupMembers(groupId: "G-1")

        #expect(result.map(\.serverID) == expected)
    }

    @Test("Repository 가 에러를 던지면 그대로 전파")
    func propagatesRepositoryError() async {
        let repository = MockStudyRepository()
        repository.fetchStudyGroupDetailError = MockStudyRepository.MockError.stubbed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockStudyRepository.MockError.stubbed) {
            _ = try await useCase.fetchStudyGroupMembers(groupId: "G-1")
        }
    }
}
