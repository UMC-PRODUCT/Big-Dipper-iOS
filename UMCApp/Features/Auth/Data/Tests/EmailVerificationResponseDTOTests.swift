import Testing
import Foundation
import CoreNetwork
@testable import AuthData

@Suite("EmailVerificationResponseDTO / VerifyEmailCodeResponseDTO")
struct EmailVerificationResponseDTOTests {

    // MARK: - EmailVerificationResponseDTO

    @Suite("EmailVerificationResponseDTO Decoding")
    struct EmailVerificationDecodingTests {

        @Test("emailVerificationId가 문자열로 내려오면 그대로 디코딩한다")
        func decodesStringId() throws {
            let json = """
            { "emailVerificationId": "51" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailVerificationResponseDTO.self, from: json)
            #expect(dto.emailVerificationId == "51")
        }

        @Test("emailVerificationId가 숫자(Int)로 내려와도 String으로 디코딩한다 (flexible)")
        func decodesNumericIdAsString() throws {
            let json = """
            { "emailVerificationId": 51 }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(EmailVerificationResponseDTO.self, from: json)
            #expect(dto.emailVerificationId == "51")
        }

        @Test("emailVerificationId 키 누락 시 빈 문자열로 디코딩한다")
        func decodesMissingIdAsEmptyString() throws {
            let json = "{}".data(using: .utf8)!
            let dto = try JSONDecoder().decode(EmailVerificationResponseDTO.self, from: json)
            #expect(dto.emailVerificationId.isEmpty)
        }
    }

    // MARK: - VerifyEmailCodeResponseDTO

    @Suite("VerifyEmailCodeResponseDTO Decoding")
    struct VerifyEmailCodeDecodingTests {

        @Test("emailVerificationToken을 그대로 디코딩한다")
        func decodesToken() throws {
            let json = """
            { "emailVerificationToken": "verify-token" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(VerifyEmailCodeResponseDTO.self, from: json)
            #expect(dto.emailVerificationToken == "verify-token")
        }

        @Test("emailVerificationToken 키 누락 시 빈 문자열로 디코딩한다")
        func decodesMissingTokenAsEmptyString() throws {
            let json = "{}".data(using: .utf8)!
            let dto = try JSONDecoder().decode(VerifyEmailCodeResponseDTO.self, from: json)
            #expect(dto.emailVerificationToken.isEmpty)
        }
    }

    // MARK: - APIResponse wrapping

    @Suite("APIResponse 래핑")
    struct APIResponseIntegrationTests {

        @Test("sendEmailVerification 성공 응답을 unwrap하면 emailVerificationId를 얻는다")
        func unwrapsSendEmailVerificationResponse() throws {
            let json = """
            {
                "success": true,
                "code": "200",
                "message": "성공",
                "result": { "emailVerificationId": 51 }
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(
                APIResponse<EmailVerificationResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()
            #expect(dto.emailVerificationId == "51")
        }
    }
}
