//
//  SearchChallengersUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDomain
import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

#if DEBUG

// MARK: - Helpers

/// `memberId` 만 검증 대상이고, 나머지 필드는 init 충족용 임의 고정값입니다.
private func makeChallenger(memberId: String) -> ChallengerInfo {
    ChallengerInfo(
        memberId: memberId,
        challengerId: "C-\(memberId)",
        gen: "9",
        name: "홍길동",
        nickname: "길동",
        schoolName: "한성대학교",
        profileImage: nil,
        part: .front(type: .ios)
    )
}

private func makeUseCase(
    repository: MockSearchMemberRepository = MockSearchMemberRepository()
) -> SearchChallengersUseCase {
    SearchChallengersUseCase(repository: repository)
}

// MARK: - Mocks

/// `searchChallengers` 만 컨트롤하는 포커스드 Mock.
/// 본 UseCase 가 호출하지 않는 나머지 계약 메서드는 호출 시 즉시 실패하도록 `unimplemented` 를 던집니다.
private final class MockSearchMemberRepository: @unchecked Sendable, MemberRepositoryProtocol {

    enum MockError: Error {
        /// 본 UseCase 가 호출하면 안 되는 계약 메서드를 건드렸음을 알리는 표식
        case unimplemented
        /// 에러 전파 경로 검증용 — Repository 가 의도적으로 실패할 때 던지는 스텁 에러
        case stubbed
    }

    /// 검색 호출 1건의 인자를 기록하는 값 타입
    struct SearchCall: Equatable {
        let keyword: String?
        let cursor: Int?
        let size: Int
    }

    // MARK: 입출력 기록

    var searchResult = ChallengerSearchPage(challengers: [], hasNext: false, nextCursor: nil)
    var searchError: Error?
    private(set) var searchCalls: [SearchCall] = []

    // MARK: 본 UseCase 가 사용하는 메서드

    func searchChallengers(
        keyword: String?,
        cursor: Int?,
        size: Int
    ) async throws -> ChallengerSearchPage {
        searchCalls.append(SearchCall(keyword: keyword, cursor: cursor, size: size))
        if let searchError { throw searchError }
        return searchResult
    }

    // MARK: 본 UseCase 미사용 — 호출 시 unimplemented

    func fetchMembers() async throws -> [MemberManagementItem] {
        throw MockError.unimplemented
    }

    func fetchMembersPage(page: Int) async throws -> MemberPage {
        throw MockError.unimplemented
    }

    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {
        throw MockError.unimplemented
    }

    func deletePoint(challengerPointId: String) async throws {
        throw MockError.unimplemented
    }

    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        throw MockError.unimplemented
    }

    func fetchAllGenerations(memberId: String) async throws -> String {
        throw MockError.unimplemented
    }

    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        throw MockError.unimplemented
    }

    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        throw MockError.unimplemented
    }
}

// MARK: - Suite: 위임 계약

@Suite("SearchChallengersUseCase — Repository 위임 (도메인 규칙)")
struct SearchChallengersUseCaseDelegationTests {

    @Test("검색 인자를 변형 없이 Repository 로 전달한다")
    func forwardsArgumentsUnchanged() async throws {
        let repository = MockSearchMemberRepository()
        let sut = makeUseCase(repository: repository)

        _ = try await sut.execute(keyword: "길동", cursor: 12, size: 30)

        #expect(
            repository.searchCalls == [
                .init(keyword: "길동", cursor: 12, size: 30)
            ]
        )
    }

    @Test("키워드·커서가 없으면 nil 그대로 전달한다 (전체 검색 첫 페이지)")
    func forwardsNilArguments() async throws {
        let repository = MockSearchMemberRepository()
        let sut = makeUseCase(repository: repository)

        _ = try await sut.execute(keyword: nil, cursor: nil, size: 50)

        #expect(
            repository.searchCalls == [
                .init(keyword: nil, cursor: nil, size: 50)
            ]
        )
    }

    @Test("Repository 페이지를 가공 없이 반환한다")
    func returnsRepositoryPageUnchanged() async throws {
        let repository = MockSearchMemberRepository()
        repository.searchResult = ChallengerSearchPage(
            challengers: [makeChallenger(memberId: "100")],
            hasNext: true,
            nextCursor: 12
        )
        let sut = makeUseCase(repository: repository)

        let page = try await sut.execute(keyword: "길동", cursor: nil, size: 50)

        #expect(page.challengers.map(\.memberId) == ["100"])
        #expect(page.hasNext)
        #expect(page.nextCursor == 12)
    }
}

// MARK: - Suite: 에러 전파

@Suite("SearchChallengersUseCase — 에러 전파 (도메인 규칙)")
struct SearchChallengersUseCaseErrorTests {

    @Test("Repository 에러를 삼키지 않고 그대로 전파한다")
    func propagatesRepositoryError() async {
        let repository = MockSearchMemberRepository()
        repository.searchError = MockSearchMemberRepository.MockError.stubbed
        let sut = makeUseCase(repository: repository)

        await #expect(throws: MockSearchMemberRepository.MockError.stubbed) {
            _ = try await sut.execute(keyword: "길동", cursor: nil, size: 50)
        }
    }
}

#endif
