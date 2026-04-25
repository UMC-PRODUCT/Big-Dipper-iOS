//
//  DefaultAuthenticationPolicyTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
@testable import CoreNetwork

@Suite("DefaultAuthenticationPolicy")
struct DefaultAuthenticationPolicyTests {

    @Test("requireAuthentication은 모든 요청에 대해 true를 반환한다")
    func requireAuthenticationAlwaysTrue() {
        let policy = DefaultAuthenticationPolicy()

        let withoutAuth = URLRequest(url: URL(string: "https://example.com/login")!)
        var withAuth = URLRequest(url: URL(string: "https://example.com/me")!)
        withAuth.setValue("Bearer test", forHTTPHeaderField: "Authorization")

        #expect(policy.requireAuthentication(withoutAuth))
        #expect(policy.requireAuthentication(withAuth))
    }

    @Test(
        "isUnauthorizedResponse는 401일 때만 true를 반환한다",
        arguments: [
            (200, false),
            (201, false),
            (204, false),
            (400, false),
            (401, true),
            (403, false),
            (404, false),
            (500, false),
        ]
    )
    func isUnauthorizedResponseOnly401(statusCode: Int, expected: Bool) throws {
        let policy = DefaultAuthenticationPolicy()
        let url = URL(string: "https://example.com/me")!
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )
        )

        #expect(policy.isUnauthorizedResponse(response) == expected)
    }
}
