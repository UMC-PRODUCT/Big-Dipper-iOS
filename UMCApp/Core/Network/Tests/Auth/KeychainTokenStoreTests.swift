//
//  KeychainTokenStoreTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 7/27/26.
//

import Foundation
import Security
import Testing
@testable import CoreNetwork

@Suite("KeychainTokenStore")
struct KeychainTokenStoreTests {

    @Test("저장 → 다른 인스턴스로 조회 → 삭제 라운드트립이 실제 Keychain에 반영된다")
    func saveGetClearRoundTrip() async throws {
        // 테스트 전용 service 네임스페이스로 실제 앱 토큰(com.ump.product)과 격리한다.
        let service = "dev.umc.core.network.tests.keychain.\(UUID().uuidString)"
        let accessTokenKey = "test.accessToken"
        let refreshTokenKey = "test.refreshToken"

        // 코드사이닝 없이 실행되는 샌드박스에서는 keychain-access-groups entitlement가
        // 임베드되지 않아 SecItemAdd가 errSecMissingEntitlement로 실패한다.
        // 실제 개발 인증서로 서명되는 로컬/CI 환경에서는 아래 라운드트립이 그대로 통과한다.
        try await withKnownIssue("샌드박스 환경의 codesign 제약으로 Keychain entitlement가 누락될 수 있다") {
            let writer = KeychainTokenStore(
                service: service,
                accessTokenKey: accessTokenKey,
                refreshTokenKey: refreshTokenKey
            )
            try await writer.save(accessToken: "test-access-token", refreshToken: "test-refresh-token")

            // 저장 인스턴스가 아닌 별도 인스턴스로 조회해 메모리 캐시가 아닌 Keychain 자체를 검증한다.
            let reader = KeychainTokenStore(
                service: service,
                accessTokenKey: accessTokenKey,
                refreshTokenKey: refreshTokenKey
            )
            #expect(await reader.getAccessToken() == "test-access-token")
            #expect(await reader.getRefreshToken() == "test-refresh-token")

            try await reader.clear()

            let verifier = KeychainTokenStore(
                service: service,
                accessTokenKey: accessTokenKey,
                refreshTokenKey: refreshTokenKey
            )
            #expect(await verifier.getAccessToken() == nil)
            #expect(await verifier.getRefreshToken() == nil)
        } matching: { issue in
            guard case .errorCaught(let error) = issue.kind,
                  let keychainError = error as? KeychainError,
                  case .saveFailed(let status) = keychainError,
                  status == errSecMissingEntitlement else {
                return false
            }
            return true
        }
    }
}
