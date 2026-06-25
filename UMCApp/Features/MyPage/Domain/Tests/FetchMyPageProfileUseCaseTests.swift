//
//  FetchMyPageProfileUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by One on 5/23/26.
//

import Testing
import Foundation
import UMCFoundation
import CoreDomain
@testable import MyPageDomain

@Suite("FetchMyPageProfileUseCase — Repository 위임 검증")
struct FetchMyPageProfileUseCaseTests {

    @Test("execute() 호출 시 repository.fetchMyProfile()의 결과를 그대로 반환한다")
    func returnsRepositoryResult() async throws {
        let expected = makeProfileData(challengeId: 42)
        let repository = StubMyPageRepository(result: .success(expected))
        let useCase = FetchMyPageProfileUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result == expected)
        #expect(repository.fetchMyProfileCallCount == 1)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let repository = StubMyPageRepository(result: .failure(StubError.network))
        let useCase = FetchMyPageProfileUseCase(repository: repository)

        await #expect(throws: StubError.network) {
            _ = try await useCase.execute()
        }
    }
}

// MARK: - Helpers

private enum StubError: Error, Equatable { case network }

private func makeProfileData(challengeId: Int) -> ProfileData {
    ProfileData(
        challengeId: challengeId,
        challengerInfo: ChallengerInfo(
            memberId: "1",
            challengerId: "1",
            gen: "11",
            name: "테스트",
            nickname: "tester",
            schoolName: "UMC",
            profileImage: nil,
            part: .pm
        ),
        socialConnections: [],
        activityLogs: [],
        profileLink: []
    )
}

private final class StubMyPageRepository: MyPageRepositoryProtocol, @unchecked Sendable {
    private let result: Result<ProfileData, StubError>
    private(set) var fetchMyProfileCallCount = 0

    init(result: Result<ProfileData, StubError>) {
        self.result = result
    }

    func fetchMyProfile() async throws -> ProfileData {
        fetchMyProfileCallCount += 1
        return try result.get()
    }

    // 미사용 메서드: 호출 시 테스트 즉시 실패
    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary {
        Issue.record("Unexpected call: fetchMemberProfile")
        throw StubError.network
    }

    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        Issue.record("Unexpected call: fetchMyPosts")
        throw StubError.network
    }

    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        Issue.record("Unexpected call: fetchCommentedPosts")
        throw StubError.network
    }

    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        Issue.record("Unexpected call: fetchScrappedPosts")
        throw StubError.network
    }

    func fetchTerms(termsType: String) async throws -> MyPageTerms {
        Issue.record("Unexpected call: fetchTerms")
        throw StubError.network
    }
}
