import Testing
import Foundation
import CoreNetwork
import UMCFoundation
@testable import AuthData

@Suite("RegisterByIdPwResponseDTO")
struct RegisterByIdPwResponseDTOTests {

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

            let dto = try JSONDecoder().decode(RegisterByIdPwResponseDTO.self, from: json)

            #expect(dto.memberId == "42")
            #expect(dto.accessToken == "access-token")
            #expect(dto.refreshToken == "refresh-token")
        }

        @Test("memberId가 숫자로 내려와도 String으로 디코딩한다 (flexible)")
        func decodesNumericMemberIdAsString() throws {
            let json = """
            { "memberId": 42, "accessToken": "a", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(RegisterByIdPwResponseDTO.self, from: json)
            #expect(dto.memberId == "42")
        }

        // MARK: - 토큰 누락(fail-open) 회귀 — Important 1 수정 후 기대 동작
        //
        // DTO 자체는 누락된 토큰을 여전히 빈 문자열로 흡수한다(레거시 호환 목적의 관용적
        // 디코딩 스타일 유지). 서버가 실제로 토큰을 누락하는 fail-open 시나리오에 대한
        // 안전 가드는 `AuthRepository.registerByEmail()`이 `register()`와 동일하게
        // 빈 문자열 여부를 검사해 `RepositoryError.decodingError`를 던지는 방식으로
        // 책임진다(Repository 계층 — 이 스위트는 DTO 계층의 순수 디코딩 계약만 검증한다).
        @Test("accessToken 키 누락 시 DTO는 빈 문자열로 디코딩된다 (가드는 Repository 책임)")
        func decodesMissingAccessTokenAsEmptyString() throws {
            let json = """
            { "memberId": "42", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(RegisterByIdPwResponseDTO.self, from: json)
            #expect(dto.accessToken.isEmpty)
            #expect(dto.refreshToken == "r")
        }

        @Test("refreshToken이 명시적 null이면 빈 문자열로 디코딩된다 (가드는 Repository 책임)")
        func decodesNullRefreshTokenAsEmptyString() throws {
            let json = """
            { "memberId": "42", "accessToken": "a", "refreshToken": null }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(RegisterByIdPwResponseDTO.self, from: json)
            #expect(dto.refreshToken.isEmpty)
        }

        @Test("accessToken이 명시적 빈 문자열이면 그대로 빈 문자열로 디코딩된다")
        func decodesExplicitEmptyStringAccessToken() throws {
            let json = """
            { "memberId": "42", "accessToken": "", "refreshToken": "r" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(RegisterByIdPwResponseDTO.self, from: json)
            #expect(dto.accessToken.isEmpty)
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
                APIResponse<RegisterByIdPwResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()

            #expect(dto.memberId == "42")
            #expect(dto.accessToken == "a")
            #expect(dto.refreshToken == "r")
        }
    }
}
