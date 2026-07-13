//
//  TermsDTOTests.swift
//  AuthDataTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
import Foundation
import CoreNetwork
import AuthDomain
@testable import AuthData

@Suite("TermsDTO")
struct TermsDTOTests {

    // MARK: - Raw JSON Decoding

    @Suite("Decoding")
    struct DecodingTests {

        @Test("필드 3개를 그대로 디코딩한다")
        func decodesAllFields() throws {
            let json = """
            { "id": "terms-1", "link": "https://umc.it.kr/terms/privacy", "isMandatory": true }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.id == "terms-1")
            #expect(dto.link == "https://umc.it.kr/terms/privacy")
            #expect(dto.isMandatory == true)
        }

        @Test("id가 숫자로 내려와도 String으로 디코딩한다 (flexible)")
        func decodesNumericIdAsString() throws {
            let json = """
            { "id": 7, "link": "https://x.com", "isMandatory": false }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.id == "7")
        }

        @Test("isMandatory:false는 그대로 false로 디코딩한다")
        func decodesIsMandatoryFalse() throws {
            let json = """
            { "id": "terms-2", "link": "https://x.com", "isMandatory": false }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.isMandatory == false)
        }

        // MARK: - fail-closed 회귀 (Minor finding)
        //
        // 서버가 isMandatory 키를 누락하면 필수 약관 검증(PM 결정 Q3)이 우회되지 않도록
        // `true`(필수)로 fail-closed 처리해야 한다. `?? false`(fail-open)로 되돌아가면
        // 이 테스트가 실패한다.
        @Test("isMandatory 키 누락 시 true로 디코딩한다 (fail-closed)")
        func decodesMissingIsMandatoryAsTrue() throws {
            let json = """
            { "id": "terms-3", "link": "https://x.com" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.isMandatory == true)
        }

        @Test("isMandatory가 해석 불가한 값이면 true로 디코딩한다 (fail-closed)")
        func decodesUnparsableIsMandatoryAsTrue() throws {
            let json = """
            { "id": "terms-4", "link": "https://x.com", "isMandatory": "unknown" }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.isMandatory == true)
        }

        @Test("link 키 누락 시 빈 문자열로 디코딩한다")
        func decodesMissingLinkAsEmptyString() throws {
            let json = """
            { "id": "terms-5", "isMandatory": true }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)
            #expect(dto.link.isEmpty)
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
                    "id": "terms-1",
                    "link": "https://umc.it.kr/terms/privacy",
                    "isMandatory": true
                }
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(APIResponse<TermsDTO>.self, from: json)
            let dto = try response.unwrap()

            #expect(dto.id == "terms-1")
            #expect(dto.isMandatory == true)
        }
    }

    // MARK: - toDomain(type:)

    @Suite("toDomain")
    struct ToDomainTests {

        @Test("DTO 필드와 호출 시점의 TermsType을 Terms로 매핑한다")
        func mapsToTermsWithInjectedType() throws {
            let json = """
            { "id": "terms-1", "link": "https://umc.it.kr/terms/service", "isMandatory": true }
            """.data(using: .utf8)!
            let dto = try JSONDecoder().decode(TermsDTO.self, from: json)

            let domain = dto.toDomain(type: .service)

            #expect(domain.id == dto.id)
            #expect(domain.link == dto.link)
            #expect(domain.isMandatory == dto.isMandatory)
            #expect(domain.type == .service)
        }
    }
}
