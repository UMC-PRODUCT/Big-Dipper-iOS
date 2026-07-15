//
//  FetchMyPageProfileUseCaseTests.swift
//  MyPageDomainTests
//
//  Created by One on 5/23/26.
//

import Testing
import Foundation
@testable import MyPageDomain

@Suite("FetchMyPageProfileUseCase — Repository 위임 검증")
struct FetchMyPageProfileUseCaseTests {

    @Test("execute() 호출 시 repository.fetchMyProfile()의 결과를 그대로 반환한다")
    func returnsRepositoryResult() async throws {
        let expected = makeStubProfileData(challengeId: 42)
        let mock = MockMyPageRepository()
        mock.fetchMyProfileResult = .success(expected)
        let useCase = FetchMyPageProfileUseCase(repository: mock)

        let result = try await useCase.execute()

        #expect(result == expected)
        #expect(mock.fetchMyProfileCallCount == 1)
        #expect(mock.fetchMyProfileReceivedForceRefresh == false)
    }

    @Test("repository가 에러를 던지면 그대로 전파한다")
    func propagatesError() async {
        let mock = MockMyPageRepository()
        mock.fetchMyProfileResult = .failure(MyPageTestError.boom)
        let useCase = FetchMyPageProfileUseCase(repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            _ = try await useCase.execute()
        }
    }

    @Test("execute(forceRefresh: true)는 forceRefresh를 repository에 그대로 관통시킨다")
    func executePassesForceRefreshThrough() async throws {
        let expected = makeStubProfileData(challengeId: 7)
        let mock = MockMyPageRepository()
        mock.fetchMyProfileResult = .success(expected)
        let useCase = FetchMyPageProfileUseCase(repository: mock)

        let result = try await useCase.execute(forceRefresh: true)

        #expect(result == expected)
        #expect(mock.fetchMyProfileReceivedForceRefresh == true)
    }
}
