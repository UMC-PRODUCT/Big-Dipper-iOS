//
//  TokenPairTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
@testable import CoreNetwork

@Suite("TokenPair")
struct TokenPairTests {

    @Test("init으로 생성한 토큰의 프로퍼티가 그대로 노출된다")
    func initSetsProperties() {
        let pair = TokenPair(accessToken: "access-1", refreshToken: "refresh-1")

        #expect(pair.accessToken == "access-1")
        #expect(pair.refreshToken == "refresh-1")
    }

    @Test("Codable round-trip 시 동일한 값이 보존된다")
    func codableRoundTrip() throws {
        let original = TokenPair(accessToken: "AAA", refreshToken: "RRR")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenPair.self, from: data)

        #expect(decoded == original)
    }

    @Test("서버 JSON 키(accessToken/refreshToken)로 디코딩된다")
    func decodesServerJSON() throws {
        let json = """
        { "accessToken": "JWT.A", "refreshToken": "JWT.R" }
        """.data(using: .utf8)!

        let pair = try JSONDecoder().decode(TokenPair.self, from: json)

        #expect(pair.accessToken == "JWT.A")
        #expect(pair.refreshToken == "JWT.R")
    }

    @Test(
        "Equatable 비교가 두 필드를 모두 검사한다",
        arguments: [
            (TokenPair(accessToken: "A", refreshToken: "R"),
             TokenPair(accessToken: "A", refreshToken: "R"), true),
            (TokenPair(accessToken: "A", refreshToken: "R"),
             TokenPair(accessToken: "A2", refreshToken: "R"), false),
            (TokenPair(accessToken: "A", refreshToken: "R"),
             TokenPair(accessToken: "A", refreshToken: "R2"), false),
        ]
    )
    func equatable(lhs: TokenPair, rhs: TokenPair, expected: Bool) {
        #expect((lhs == rhs) == expected)
    }
}
