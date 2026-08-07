//
//  EmailLoginResponseDTOTests.swift
//  AuthDataTests
//
//  Created by euijjang97 on 7/31/26.
//

import Testing
import Foundation
import CoreNetwork
import UMCFoundation
@testable import AuthData

@Suite("EmailLoginResponseDTO")
struct EmailLoginResponseDTOTests {

    // MARK: - Raw JSON Decoding

    @Suite("Decoding")
    struct DecodingTests {

        @Test("필드 3개를 그대로 디코딩한다")
        func decodesAllFields() throws {
            let json = """
            {
                "memberId": "42",
                "accessToken": "access-token",
                "refreshToken": "refresh-token"
            }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)

            #expect(dto.memberId == "42")
            #expect(dto.accessToken == "access-token")
            #expect(dto.refreshToken == "refresh-token")
        }

        @Test("memberId가 숫자로 내려와도 String으로 디코딩한다 (flexible)")
        func decodesNumericMemberIdAsString() throws {
            let json = """
            { "memberId": 42, "accessToken": "a", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)
            #expect(dto.memberId == "42")
        }

        @Test("memberId 키가 누락되면 빈 문자열로 디코딩된다")
        func decodesMissingMemberIdAsEmptyString() throws {
            let json = """
            { "accessToken": "a", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)
            #expect(dto.memberId.isEmpty)
        }

        // MARK: - 토큰 누락(fail-open) 계약
        //
        // DTO는 누락된 토큰을 빈 문자열로 흡수하고, 빈 토큰을 유효 세션으로 저장하지 않도록
        // 하는 가드는 `AuthRepository.loginByEmail()`이 책임진다
        // (`RegisterByIdPwResponseDTO`와 동일 — 이 스위트는 순수 디코딩 계약만 검증한다).
        @Test("accessToken 키 누락 시 DTO는 빈 문자열로 디코딩된다 (가드는 Repository 책임)")
        func decodesMissingAccessTokenAsEmptyString() throws {
            let json = """
            { "memberId": "42", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)
            #expect(dto.accessToken.isEmpty)
            #expect(dto.refreshToken == "r")
        }

        @Test("refreshToken이 명시적 null이면 빈 문자열로 디코딩된다 (가드는 Repository 책임)")
        func decodesNullRefreshTokenAsEmptyString() throws {
            let json = """
            { "memberId": "42", "accessToken": "a", "refreshToken": null }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)
            #expect(dto.refreshToken.isEmpty)
        }

        @Test("memberId가 명시적 null이면 빈 문자열로 디코딩된다")
        func decodesNullMemberIdAsEmptyString() throws {
            let json = """
            { "memberId": null, "accessToken": "a", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailLoginResponseDTO.self, from: json)
            #expect(dto.memberId.isEmpty)
        }
    }

    // MARK: - APIResponse wrapping

    @Suite("APIResponse 래핑")
    struct APIResponseIntegrationTests {

        @Test("성공 응답을 unwrap하면 DTO를 얻는다")
        func unwrapsSuccessfulResponse() throws {
            let json = """
            {
                "success": true,
                "code": "200",
                "message": "성공",
                "result": {
                    "memberId": "42",
                    "accessToken": "a",
                    "refreshToken": "r"
                }
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(
                APIResponse<EmailLoginResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()

            #expect(dto.memberId == "42")
            #expect(dto.accessToken == "a")
            #expect(dto.refreshToken == "r")
        }
    }
}
