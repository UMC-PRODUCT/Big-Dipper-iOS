//
//  FetchUserIdUseCaseTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 6/26/26.
//

import Foundation
import Testing
@testable import ActivityDomain

#if DEBUG

// MARK: - Helpers

private func makeUseCase(
    provider: MockCurrentUserIdProvider = MockCurrentUserIdProvider()
) -> FetchUserIdUseCase {
    FetchUserIdUseCase(provider: provider)
}

// MARK: - Mocks

/// `CurrentUserIdProviding` 의 단일 메서드를 제어하는 Mock.
private final class MockCurrentUserIdProvider: @unchecked Sendable, CurrentUserIdProviding {

    enum MockError: Error {
        /// 에러 전파 경로 검증용 스텁 에러
        case stubbed
    }

    var result = UserID(value: "0")
    var error: Error?
    private(set) var callCount = 0

    func fetchCurrentUserId() async throws -> UserID {
        callCount += 1
        if let error { throw error }
        return result
    }
}

// MARK: - 위임 계약

@Suite("FetchUserIdUseCase — 현재 사용자 식별자 위임 (도메인 규칙)")
struct FetchUserIdUseCaseTests {

    @Test("execute — provider 의 UserID 를 그대로 반환하고 1회 호출")
    func executeReturnsProviderUserId() async throws {
        let provider = MockCurrentUserIdProvider()
        provider.result = UserID(value: "42")
        let useCase = makeUseCase(provider: provider)

        let userId = try await useCase.execute()

        #expect(userId == UserID(value: "42"))
        #expect(provider.callCount == 1)
    }

    @Test("execute — provider 에러를 그대로 전파")
    func executePropagatesProviderError() async {
        let provider = MockCurrentUserIdProvider()
        provider.error = MockCurrentUserIdProvider.MockError.stubbed
        let useCase = makeUseCase(provider: provider)

        await #expect(throws: MockCurrentUserIdProvider.MockError.stubbed) {
            _ = try await useCase.execute()
        }
    }
}

#endif
