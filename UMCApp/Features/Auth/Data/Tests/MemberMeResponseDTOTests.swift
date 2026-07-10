import Testing
import Foundation
import AuthDomain
@testable import AuthData

@Suite("MemberMeResponseDTO — 내 프로필 조회 응답 디코딩/도메인 매핑")
struct MemberMeResponseDTOTests {

    @Test("복수 challengerRecords 중 숫자 기수가 가장 큰 레코드를 최신 기록으로 채택한다")
    func picksLatestRecordByMaxGisu() throws {
        let json = """
        {
            "id": 1,
            "name": "김철수",
            "nickname": "철수",
            "schoolId": 900,
            "schoolName": "한국대학교",
            "roles": [],
            "challengerRecords": [
                {
                    "gisu": 10, "challengerId": 111, "gisuId": 210,
                    "chapterId": 300, "chapterName": "서울", "part": "IOS",
                    "schoolId": 900, "schoolName": "한국대학교"
                },
                {
                    "gisu": 11, "challengerId": 222, "gisuId": 211,
                    "chapterId": 301, "chapterName": "부산", "part": "ANDROID",
                    "schoolId": 900, "schoolName": "한국대학교"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        #expect(profile.latestChallengerId == "222")
        #expect(profile.latestGisuId == "211")
        #expect(profile.chapterId == "301")
        #expect(profile.chapterName == "부산")
        #expect(profile.responsiblePart == "ANDROID")
    }

    @Test("역할/챌린저 기록의 기수 번호 합집합에서 빈 값과 \"0\"을 제외해 정렬한다")
    func mergesGenerationsExcludingZeroAndEmpty() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                { "gisu": "0", "roleType": "CHALLENGER", "organizationType": "CHAPTER", "organizationId": null },
                { "gisu": "10", "roleType": "CHALLENGER", "organizationType": "CHAPTER", "organizationId": null }
            ],
            "challengerRecords": [
                {
                    "gisu": "11", "challengerId": "1", "gisuId": "1",
                    "part": "IOS", "schoolId": "1", "schoolName": "S"
                },
                {
                    "gisu": "", "challengerId": "2", "gisuId": "2",
                    "part": "IOS", "schoolId": "1", "schoolName": "S"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        #expect(profile.generations == ["10", "11"])
    }

    @Test("기수 번호를 사전식이 아닌 숫자 크기로 정렬한다 (\"9\"/\"10\" 자릿수 역전 회귀 테스트)")
    func sortsGenerationsNumerically() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                {
                    "gisu": "10", "roleType": "CHALLENGER",
                    "organizationType": "CHAPTER", "organizationId": null
                }
            ],
            "challengerRecords": [
                {
                    "gisu": "9", "challengerId": "1", "gisuId": "1",
                    "part": "IOS", "schoolId": "1", "schoolName": "S"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        #expect(profile.generations == ["9", "10"])
    }

    @Test("정수로 내려오는 식별자 필드를 String으로 유연하게 디코딩한다")
    func decodesNumericIdentifiersAsStrings() throws {
        let json = """
        {
            "id": 42,
            "name": "A",
            "nickname": "a",
            "schoolId": 900,
            "schoolName": "한국대학교",
            "roles": [
                {
                    "gisu": 11, "roleType": "SCHOOL_PART_LEADER",
                    "organizationType": "SCHOOL", "organizationId": 700
                }
            ],
            "challengerRecords": [
                {
                    "gisu": 11, "challengerId": 555, "gisuId": 77,
                    "chapterId": 300, "chapterName": "서울", "part": "IOS",
                    "schoolId": 900, "schoolName": "한국대학교"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)

        #expect(dto.id == "42")
        #expect(dto.schoolId == "900")
        #expect(dto.roles.first?.gisu == "11")
        #expect(dto.roles.first?.organizationId == "700")
        #expect(dto.challengerRecords.first?.challengerId == "555")
        #expect(dto.challengerRecords.first?.gisuId == "77")
        #expect(dto.challengerRecords.first?.chapterId == "300")
    }

    @Test("roleType/organizationType 키가 없으면 각각 challenger/central로 폴백한다")
    func fallsBackToDefaultRoleAndOrganizationTypeWhenKeysAreMissing() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                { "gisu": "11", "organizationId": null }
            ],
            "challengerRecords": []
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)

        #expect(dto.roles.first?.roleType == .challenger)
        #expect(dto.roles.first?.organizationType == .central)
    }

    @Test("roles와 challengerRecords의 조직 정보를 기수별로 병합해 generationOrganizations를 구성한다")
    func buildsGenerationOrganizationsMergingRolesAndRecords() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                {
                    "gisu": "11", "roleType": "SCHOOL_PART_LEADER",
                    "organizationType": "SCHOOL", "organizationId": "900"
                }
            ],
            "challengerRecords": [
                {
                    "gisu": "11", "challengerId": "1", "gisuId": "1",
                    "chapterId": "300", "chapterName": "서울",
                    "part": "IOS", "schoolId": "0", "schoolName": ""
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        let generationOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "11" }
        )
        #expect(generationOrganization.chapterId == "300")
        #expect(generationOrganization.chapterName == "서울")
        // challengerRecords의 schoolId가 "0"이라 무효 처리되고, roles의 organizationId(900)로 보강된다.
        #expect(generationOrganization.schoolId == "900")
    }

    @Test("challengerRecords가 없는 기수도 roles의 조직 정보만으로 generationOrganizations 항목을 만든다")
    func buildsGenerationOrganizationsFromRolesOnlyGeneration() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                {
                    "gisu": "12", "roleType": "CHAPTER_PRESIDENT",
                    "organizationType": "CHAPTER", "organizationId": "310"
                },
                {
                    "gisu": "0", "roleType": "CHALLENGER",
                    "organizationType": "CHAPTER", "organizationId": "999"
                }
            ],
            "challengerRecords": [
                {
                    "gisu": "11", "challengerId": "1", "gisuId": "1",
                    "chapterId": "300", "chapterName": "서울",
                    "part": "IOS", "schoolId": "900", "schoolName": "한국대학교"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        // 기수 "0" 역할은 제외되고, 숫자 크기 순으로 정렬된다.
        #expect(profile.generationOrganizations.map(\.gen) == ["11", "12"])

        let rolesOnlyOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "12" }
        )
        #expect(rolesOnlyOrganization.chapterId == "310")
        #expect(rolesOnlyOrganization.chapterName == nil)
        #expect(rolesOnlyOrganization.schoolId == nil)
        #expect(rolesOnlyOrganization.schoolName == nil)
    }

    @Test("challengerRecords의 chapterId 누락을 같은 기수 chapter 역할의 organizationId로 backfill한다")
    func backfillsMissingChapterIdFromChapterRole() throws {
        let json = """
        {
            "id": 1,
            "name": "A",
            "nickname": "a",
            "roles": [
                {
                    "gisu": "11", "roleType": "CHAPTER_PRESIDENT",
                    "organizationType": "CHAPTER", "organizationId": "305"
                }
            ],
            "challengerRecords": [
                {
                    "gisu": "11", "challengerId": "1", "gisuId": "1",
                    "chapterId": null, "chapterName": null,
                    "part": "IOS", "schoolId": "900", "schoolName": "한국대학교"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MemberMeResponseDTO.self, from: json)
        let profile = dto.toDomain()

        let generationOrganization = try #require(
            profile.generationOrganizations.first { $0.gen == "11" }
        )
        #expect(generationOrganization.chapterId == "305")
        // chapter 역할 backfill은 record의 학교 정보를 덮어쓰지 않고 보존한다.
        #expect(generationOrganization.schoolId == "900")
        #expect(generationOrganization.schoolName == "한국대학교")
    }
}
