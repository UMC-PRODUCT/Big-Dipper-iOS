//
//  StorageRepositoryTests.swift
//  CoreNetworkTests
//
//  외부 스토리지 업로드(uploadFile)의 상태코드 매핑 및 URLError 흡수 검증.
//

import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

@MainActor
@Suite("StorageRepository — uploadFile", .serialized)
struct StorageRepositoryTests {

    private let uploadURL = "https://storage.umc.test/upload/abc"

    private func makeRepository() -> StorageRepository {
        StubURLProtocol.reset()
        let store = MockTokenStore()
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = NetworkClient(session: makeStubSession(), tokenStore: store, refreshService: refresh)
        let adapter = MoyaNetworkAdapter(networkClient: client, baseURL: URL(string: "https://api.umc.test")!)
        return StorageRepository(adapter: adapter, session: makeStubSession())
    }

    @Test("업로드 중 연결 없음은 NetworkError.noNetwork 로 흡수된다")
    func absorbsNoNetwork() async {
        let repo = makeRepository()
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: NetworkError.noNetwork) {
            try await repo.uploadFile(to: uploadURL, data: Data("x".utf8),
                                      method: "PUT", headers: nil, contentType: "image/png")
        }
    }
}
