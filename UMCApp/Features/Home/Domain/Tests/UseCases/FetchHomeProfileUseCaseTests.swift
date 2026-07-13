//
//  FetchHomeProfileUseCaseTests.swift
//  HomeDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
@testable import HomeDomain

@Suite("FetchHomeProfileUseCase — Repository 위임 검증")
struct FetchHomeProfileUseCaseTests {

    @Test("execute() 호출 시 repository.fetchMyProfile() 결과를 그대로 반환한다")
    func executeDelegatesToRepository() async throws {
        let repository = MockHomeRepository()
        let expected = HomeProfileResult(
            memberId: "1",
            seasonTypes: [.gens(["11", "12"]), .days(128)],
            generations: [
                HomeGeneration(gisuId: "10", gen: "11", penaltyPoint: 3, rewardPoint: 2, pointLogs: []),
            ]
        )
        repository.fetchMyProfileResult = .success(expected)
        let useCase = FetchHomeProfileUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result == expected)
        #expect(repository.fetchMyProfileCallCount == 1)
    }

    @Test("repository.fetchMyProfile()이 에러를 던지면 그대로 전파한다")
    func executePropagatesError() async {
        let repository = MockHomeRepository()
        repository.fetchMyProfileResult = .failure(HomeTestError.boom)
        let useCase = FetchHomeProfileUseCase(repository: repository)

        await #expect(throws: HomeTestError.boom) {
            _ = try await useCase.execute()
        }
    }
}
