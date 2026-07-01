//
//  MockTokenStore.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import UMCFoundation
@testable import CoreNetwork

/// 메모리 기반 Mock TokenStore — Keychain을 거치지 않고 동작 확인용
actor MockTokenStore: TokenStore {

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var saveCallCount: Int = 0
    private(set) var clearCallCount: Int = 0

    init(accessToken: String? = nil, refreshToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func getAccessToken() async -> String? { accessToken }
    func getRefreshToken() async -> String? { refreshToken }

    func save(accessToken: String, refreshToken: String) async throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.saveCallCount += 1
    }

    func clear() async throws {
        accessToken = nil
        refreshToken = nil
        clearCallCount += 1
    }
}

/// 토큰 갱신 동작을 시나리오로 주입할 수 있는 Mock RefreshService
actor MockTokenRefreshService: TokenRefreshService {

    enum Behavior: Sendable {
        case success(TokenPair)
        case failure(MockRefreshError)
        /// 호출 시 sleep 후 success — single-flight 테스트에 사용
        case delayedSuccess(TokenPair, nanoseconds: UInt64)
        /// NetworkError 를 던짐 — NetworkClient passthrough 검증용
        case failureError(NetworkError)
    }

    private var behavior: Behavior
    private(set) var callCount: Int = 0
    private(set) var receivedRefreshTokens: [String] = []

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func updateBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func refresh(_ refreshToken: String) async throws -> TokenPair {
        callCount += 1
        receivedRefreshTokens.append(refreshToken)

        switch behavior {
        case .success(let pair):
            return pair
        case .failure(let error):
            throw error
        case .delayedSuccess(let pair, let nanoseconds):
            try? await Task.sleep(nanoseconds: nanoseconds)
            return pair
        case .failureError(let error):
            throw error
        }
    }
}

enum MockRefreshError: Error, Sendable, Equatable {
    case invalidRefreshToken
    case networkUnavailable
}
