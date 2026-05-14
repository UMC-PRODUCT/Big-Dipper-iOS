//
//  MyPageTermsResponseDTOTest.swift
//  MyPageData
//
//  Created by One on 5/10/26.
//

import Foundation
import Testing
import CoreNetwork
import UMCFoundation
@testable import MyPageData
@testable import MyPageDomain

@Suite("MyPageTermsResponseDTO")
struct MyPageTermsResponseDTOTests {

    // MARK: - Raw JSON Decoding

    @Suite("Decoding")
    struct DecodingTests {

        @Test("필드 3개를 그대로 디코딩한다")
        func decodesAllFields() throws {
            let json = """
            {
                "id": "terms-1",
                "link": "https://umc.it.kr/terms/privacy",
                "isMandatory": true
            }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(MyPageTermsResponseDTO.self, from: json)

            #expect(dto.id == "terms-1")
            #expect(dto.link == "https://umc.it.kr/terms/privacy")
            #expect(dto.isMandatory == true)
        }

        @Test("isMandatory false 케이스")
        func decodesIsMandatoryFalse() throws {
            let json = """
            { "id": "terms-2", "link": "https://x.com", "isMandatory": false }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(MyPageTermsResponseDTO.self, from: json)

            #expect(dto.isMandatory == false)
        }

        @Test("필수 필드 누락 시 throw한다")
        func throwsOnMissingField() {
            let json = """
            { "id": "terms-1", "link": "https://x.com" }
            """.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(MyPageTermsResponseDTO.self, from: json)
            }
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

            let response = try JSONDecoder().decode(
                APIResponse<MyPageTermsResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()

            #expect(dto.id == "terms-1")
            #expect(dto.isMandatory == true)
        }

        @Test("실패 응답은 RepositoryError.serverError를 throw한다")
        func failureThrowsServerError() throws {
            let json = """
            {
                "success": false,
                "code": "TERMS001",
                "message": "약관을 찾을 수 없습니다",
                "result": null
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(
                APIResponse<MyPageTermsResponseDTO>.self,
                from: json
            )

            #expect(throws: RepositoryError.serverError(
                code: "TERMS001",
                message: "약관을 찾을 수 없습니다"
            )) {
                _ = try response.unwrap()
            }
        }
    }

    // MARK: - toDomain()

    @Suite("toDomain")
    struct ToDomainTests {

        @Test("DTO 필드를 MyPageTerms로 1:1 매핑한다")
        func mapsToMyPageTerms() throws {
            let json = """
            {
                "id": "terms-1",
                "link": "https://umc.it.kr/terms/privacy",
                "isMandatory": true
            }
            """.data(using: .utf8)!
            let dto = try JSONDecoder().decode(MyPageTermsResponseDTO.self, from: json)

            let domain = dto.toDomain()

            #expect(domain.id == dto.id)
            #expect(domain.link == dto.link)
            #expect(domain.isMandatory == dto.isMandatory)
        }
    }
}
