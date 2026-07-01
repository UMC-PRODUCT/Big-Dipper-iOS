//
//  MoyaNetworkAdapterTests.swift
//  CoreNetworkTests
//
//  requestWithoutAuth 의 상태코드 매핑 및 URLError 흡수를 검증.
//

import Foundation
import Testing
import Moya
import UMCFoundation
@testable import CoreNetwork

@MainActor
@Suite("MoyaNetworkAdapter — requestWithoutAuth", .serialized)
struct MoyaNetworkAdapterTests {

    private let baseURL = URL(string: "https://api.umc.test")!

    private func makeAdapter() -> MoyaNetworkAdapter {
        StubURLProtocol.reset()
        let store = MockTokenStore()
        let refresh = MockTokenRefreshService(behavior: .success(TokenPair(accessToken: "A", refreshToken: "R")))
        let client = NetworkClient(session: makeStubSession(), tokenStore: store, refreshService: refresh)
        return MoyaNetworkAdapter(networkClient: client, baseURL: baseURL, session: makeStubSession())
    }

    @Test("연결 없음 URLError 는 NetworkError.noNetwork 로 흡수된다")
    func absorbsNoNetwork() async {
        let adapter = makeAdapter()
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: NetworkError.noNetwork) {
            _ = try await adapter.requestWithoutAuth(StubTarget())
        }
    }
}

private struct StubTarget: TargetType {
    var baseURL: URL { URL(string: "https://api.umc.test")! }
    var path: String { "/api/v1/auth/login" }
    var method: Moya.Method { .post }
    var task: Moya.Task { .requestPlain }
    var headers: [String: String]? { nil }
}
