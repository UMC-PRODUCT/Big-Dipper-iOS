//
//  OperatorStudyManagementUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

#if DEBUG

// MARK: - Helpers

private func makeUseCase(
    repository: MockStudyRepository = MockStudyRepository()
) -> OperatorStudyManagementUseCase {
    OperatorStudyManagementUseCase(repository: repository)
}

// MARK: - Mocks

/// 운영진 스터디 관리 UseCase 가 사용하는 9개 메서드를 기록/제어하는 포커스드 Mock.
/// 본 UseCase 가 호출하지 않는 계약 메서드는 호출 시 `unimplemented` 로 즉시 실패시킵니다.
private final class MockStudyRepository: @unchecked Sendable, StudyRepositoryProtocol {

    enum MockError: Error {
        /// 본 UseCase 가 호출하면 안 되는 계약 메서드를 건드렸음을 알리는 표식
        case unimplemented
        /// 에러 전파 경로 검증용 스텁 에러
        case stubbed
    }

    /// update/delete/멤버·멘토 추가·제거의 위임 인자를 한 형태로 기록.
    struct Mutation: Equatable {
        let kind: String
        let groupId: String
        let id: String
    }

    // MARK: 기록 / 제어

    var fetchPageResult = StudyGroupDetailsPage(content: [], hasNext: false, nextCursor: nil)
    var resolveResult: String? = "C-1"
    var errorToThrow: Error?

    private(set) var fetchPageCalls: [(cursor: String?, size: Int)] = []
    private(set) var resolveCalls: [(memberId: String, preferredGeneration: String?)] = []
    private(set) var createCalls: [(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    )] = []
    private(set) var mutationCalls: [Mutation] = []

    // MARK: 본 UseCase 가 사용하는 메서드

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        if let errorToThrow { throw errorToThrow }
        fetchPageCalls.append((cursor, size))
        return fetchPageResult
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        if let errorToThrow { throw errorToThrow }
        resolveCalls.append((memberId, preferredGeneration))
        return resolveResult
    }

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        if let errorToThrow { throw errorToThrow }
        createCalls.append((gisuId, name, part, memberIds, mentorIds))
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "update", groupId: groupId, id: name))
    }

    func deleteStudyGroup(groupId: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "delete", groupId: groupId, id: ""))
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "addMember", groupId: groupId, id: memberId))
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "removeMember", groupId: groupId, id: memberId))
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "addMentor", groupId: groupId, id: mentorId))
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        if let errorToThrow { throw errorToThrow }
        mutationCalls.append(Mutation(kind: "removeMentor", groupId: groupId, id: mentorId))
    }

    // MARK: 본 UseCase 미사용 — 호출 시 unimplemented

    func fetchCurriculumOverview() async throws -> CurriculumOverview {
        throw MockError.unimplemented
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        throw MockError.unimplemented
    }

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        throw MockError.unimplemented
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
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

// MARK: - 위임 메서드 디스패치

/// 9개 위임 메서드를 파라미터화해 에러 전파/변경 위임을 형제 대칭으로 검증하기 위한 디스패처.
private enum DelegatingMethod: CaseIterable {
    case fetchPage, resolve, create
    case update, delete, addMember, removeMember, addMentor, removeMentor

    /// update/delete/멤버·멘토 변경처럼 `Mutation` 으로 기록되는 케이스만 추림.
    static let mutationCases: [DelegatingMethod] = [
        .update, .delete, .addMember, .removeMember, .addMentor, .removeMentor
    ]

    func invoke(_ useCase: OperatorStudyManagementUseCase) async throws {
        switch self {
        case .fetchPage:
            _ = try await useCase.fetchStudyGroupDetailsPage(cursor: "1", size: 20)
        case .resolve:
            _ = try await useCase.resolveChallengerId(memberId: "M-1", preferredGeneration: "11")
        case .create:
            try await useCase.createStudyGroup(
                gisuId: "11",
                name: "n",
                part: .front(type: .ios),
                memberIds: [],
                mentorIds: []
            )
        case .update:
            try await useCase.updateStudyGroup(groupId: "G-1", name: "새 이름")
        case .delete:
            try await useCase.deleteStudyGroup(groupId: "G-1")
        case .addMember:
            try await useCase.addStudyGroupMember(groupId: "G-1", memberId: "M-1")
        case .removeMember:
            try await useCase.removeStudyGroupMember(groupId: "G-1", memberId: "M-1")
        case .addMentor:
            try await useCase.addStudyGroupMentor(groupId: "G-1", mentorId: "M-9")
        case .removeMentor:
            try await useCase.removeStudyGroupMentor(groupId: "G-1", mentorId: "M-9")
        }
    }

    /// `mutationCases` 가 기대하는 기록값.
    var expectedMutation: MockStudyRepository.Mutation? {
        switch self {
        case .update: return .init(kind: "update", groupId: "G-1", id: "새 이름")
        case .delete: return .init(kind: "delete", groupId: "G-1", id: "")
        case .addMember: return .init(kind: "addMember", groupId: "G-1", id: "M-1")
        case .removeMember: return .init(kind: "removeMember", groupId: "G-1", id: "M-1")
        case .addMentor: return .init(kind: "addMentor", groupId: "G-1", id: "M-9")
        case .removeMentor: return .init(kind: "removeMentor", groupId: "G-1", id: "M-9")
        case .fetchPage, .resolve, .create: return nil
        }
    }
}

// MARK: - 페이지 커서 / 기수 변환

@Suite("OperatorStudyManagementUseCase — Repository 위임 (도메인 규칙)")
struct OperatorStudyManagementUseCaseTests {

    @Test(
        "페이지 커서 — 불투명 토큰 포함 String 을 변형 없이 Repository 로 위임",
        arguments: [
            String?.none,
            "42",
            // 불투명 토큰: 숫자로 강제 변환하면 nil 로 유실돼 페이지네이션이 깨진다.
            "cursor-2"
        ]
    )
    func fetchPageForwardsCursorVerbatim(cursor: String?) async throws {
        let repository = MockStudyRepository()
        let useCase = makeUseCase(repository: repository)

        _ = try await useCase.fetchStudyGroupDetailsPage(cursor: cursor, size: 20)

        let call = try #require(repository.fetchPageCalls.first)
        #expect(call.cursor == cursor)
        #expect(call.size == 20)
    }

    @Test(
        "챌린저 ID 조회 — String 기수를 변형 없이 위임 + memberId 그대로 위임",
        arguments: [String?.none, "11"]
    )
    func resolveForwardsGenerationVerbatim(generation: String?) async throws {
        let repository = MockStudyRepository()
        let useCase = makeUseCase(repository: repository)

        _ = try await useCase.resolveChallengerId(
            memberId: "M-1",
            preferredGeneration: generation
        )

        let call = try #require(repository.resolveCalls.first)
        #expect(call.memberId == "M-1")
        #expect(call.preferredGeneration == generation)
    }

    // MARK: - 생성 / 변경 위임

    @Test("그룹 생성 — 인자를 변형 없이 Repository 에 위임")
    func createForwardsArguments() async throws {
        let repository = MockStudyRepository()
        let useCase = makeUseCase(repository: repository)

        try await useCase.createStudyGroup(
            gisuId: "11",
            name: "iOS 스터디",
            part: .front(type: .ios),
            memberIds: ["1", "2"],
            mentorIds: ["9"]
        )

        let call = try #require(repository.createCalls.first)
        #expect(call.gisuId == "11")
        #expect(call.name == "iOS 스터디")
        #expect(call.part == .front(type: .ios))
        #expect(call.memberIds == ["1", "2"])
        #expect(call.mentorIds == ["9"])
    }

    @Test(
        "그룹 수정/삭제 · 멤버/멘토 추가·제거 — groupId/식별자를 그대로 위임",
        arguments: DelegatingMethod.mutationCases
    )
    private func mutationForwardsIdentifiers(method: DelegatingMethod) async throws {
        let repository = MockStudyRepository()
        let useCase = makeUseCase(repository: repository)

        try await method.invoke(useCase)

        #expect(repository.mutationCalls == [method.expectedMutation].compactMap { $0 })
    }

    // MARK: - 에러 전파 (형제 대칭)

    @Test(
        "Repository 에러는 모든 위임 메서드에서 그대로 전파",
        arguments: DelegatingMethod.allCases
    )
    private func propagatesRepositoryError(method: DelegatingMethod) async {
        let repository = MockStudyRepository()
        repository.errorToThrow = MockStudyRepository.MockError.stubbed
        let useCase = makeUseCase(repository: repository)

        await #expect(throws: MockStudyRepository.MockError.stubbed) {
            try await method.invoke(useCase)
        }
    }
}

#endif
