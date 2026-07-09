import Testing
import Foundation
import CoreNetwork
import AuthDomain
@testable import AuthData

@Suite("SchoolListResponseDTO / SchoolDTO")
struct SchoolListResponseDTOTests {

    // MARK: - Raw JSON Decoding

    @Suite("Decoding")
    struct DecodingTests {

        @Test("schoolId가 문자열로 내려오면 그대로 디코딩한다")
        func decodesStringSchoolId() throws {
            let json = """
            { "schools": [ { "schoolId": "1", "schoolName": "한성대" } ] }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(SchoolListResponseDTO.self, from: json)
            let school = try #require(dto.schools.first)
            #expect(school.schoolId == "1")
            #expect(school.schoolName == "한성대")
        }

        @Test("schoolId가 숫자(Int)로 내려와도 String으로 디코딩한다 (flexible)")
        func decodesNumericSchoolIdAsString() throws {
            let json = """
            { "schools": [ { "schoolId": 1, "schoolName": "한성대" } ] }
            """.data(using: .utf8)!

            let dto = try JSONDecoder().decode(SchoolListResponseDTO.self, from: json)
            let school = try #require(dto.schools.first)
            #expect(school.schoolId == "1")
        }

        @Test("schools 키 누락 시 빈 배열로 디코딩한다")
        func decodesMissingSchoolsAsEmptyArray() throws {
            let json = "{}".data(using: .utf8)!
            let dto = try JSONDecoder().decode(SchoolListResponseDTO.self, from: json)
            #expect(dto.schools.isEmpty)
        }
    }

    // MARK: - APIResponse wrapping

    @Suite("APIResponse 래핑")
    struct APIResponseIntegrationTests {

        @Test("성공 응답을 unwrap하면 학교 목록을 얻는다")
        func unwrapsSuccessfulResponse() throws {
            let json = """
            {
                "success": true,
                "code": "200",
                "message": "성공",
                "result": {
                    "schools": [
                        { "schoolId": 1, "schoolName": "한성대" },
                        { "schoolId": "2", "schoolName": "숭실대" }
                    ]
                }
            }
            """.data(using: .utf8)!

            let response = try JSONDecoder().decode(
                APIResponse<SchoolListResponseDTO>.self,
                from: json
            )
            let dto = try response.unwrap()

            #expect(dto.schools.count == 2)
            #expect(dto.schools.map(\.schoolId) == ["1", "2"])
        }
    }

    // MARK: - toDomain()

    @Suite("toDomain")
    struct ToDomainTests {

        @Test("SchoolDTO를 School로 1:1 매핑한다")
        func mapsToSchool() throws {
            let json = """
            { "schoolId": 1, "schoolName": "한성대" }
            """.data(using: .utf8)!
            let dto = try JSONDecoder().decode(SchoolDTO.self, from: json)

            let domain = dto.toDomain()

            #expect(domain.id == "1")
            #expect(domain.name == "한성대")
        }
    }
}
