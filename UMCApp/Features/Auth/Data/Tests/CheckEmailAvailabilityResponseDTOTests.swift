import Testing
import Foundation
import CoreNetwork
@testable import AuthData

@Suite("CheckEmailAvailabilityResponseDTO")
struct CheckEmailAvailabilityResponseDTOTests {

    // MARK: - Raw JSON Decoding

    @Suite("Decoding")
    struct DecodingTests {

        @Test("available:true를 그대로 디코딩한다")
        func decodesAvailableTrue() throws {
            let json = """
            { "email": "a@umc.kr", "available": true }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(CheckEmailAvailabilityResponseDTO.self, from: json)
            #expect(dto.email == "a@umc.kr")
            #expect(dto.available == true)
        }

        @Test("available:false를 그대로 디코딩한다")
        func decodesAvailableFalse() throws {
            let json = """
            { "email": "a@umc.kr", "available": false }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(CheckEmailAvailabilityResponseDTO.self, from: json)
            #expect(dto.available == false)
        }

        @Test("available이 문자열(\"true\"/\"false\")로 내려와도 Bool로 디코딩한다 (flexible)")
        func decodesStringAvailableAsBool() throws {
            let trueJSON = """
            { "email": "a@umc.kr", "available": "true" }
            """.data(using: .utf8)!
            let falseJSON = """
            { "email": "a@umc.kr", "available": "false" }
            """.data(using: .utf8)!

            let trueDTO = try JSONDecoder().decode(
                CheckEmailAvailabilityResponseDTO.self, from: trueJSON
            )
            let falseDTO = try JSONDecoder().decode(
                CheckEmailAvailabilityResponseDTO.self, from: falseJSON
            )
            #expect(trueDTO.available == true)
            #expect(falseDTO.available == false)
        }

        @Test("available이 숫자(0/1)로 내려와도 Bool로 디코딩한다 (flexible)")
        func decodesNumericAvailableAsBool() throws {
            let json = """
            { "email": "a@umc.kr", "available": 1 }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(CheckEmailAvailabilityResponseDTO.self, from: json)
            #expect(dto.available == true)
        }

        @Test("available 키 누락 시 false로 디코딩한다 (사용 불가 쪽으로 fail-closed)")
        func decodesMissingAvailableAsFalse() throws {
            let json = """
            { "email": "a@umc.kr" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(CheckEmailAvailabilityResponseDTO.self, from: json)
            #expect(dto.available == false)
        }

        @Test("email 키 누락 시 빈 문자열로 디코딩한다")
        func decodesMissingEmailAsEmptyString() throws {
            let json = """
            { "available": true }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(CheckEmailAvailabilityResponseDTO.self, from: json)
            #expect(dto.email.isEmpty)
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
                "result": { "email": "a@umc.kr", "available": true }
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(
                APIResponse<CheckEmailAvailabilityResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()

            #expect(dto.email == "a@umc.kr")
            #expect(dto.available == true)
        }
    }
}
