//
//  StudyGroupDetailDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Helpers

private func decodeDetail(_ json: String) throws -> StudyGroupDetailDTO {
    try JSONDecoder().decode(StudyGroupDetailDTO.self, from: Data(json.utf8))
}

private func makeFullDetailJSON(
    groupId: String = "\"10\"",
    part: String = "\"IOS\"",
    createdAt: String = "2026-05-11T09:30:00Z"
) -> String {
    """
    {
        "groupId": \(groupId),
        "name": "iOS 1팀",
        "part": \(part),
        "partDisplayName": "iOS",
        "schools": [
            {
                "schoolId": "100",
                "schoolName": "한성대학교",
                "logoImageId": "200",
                "totalStudyGroupCount": 3,
                "totalMemberCount": 24
            }
        ],
        "createdAt": "\(createdAt)",
        "memberCount": 5,
        "mentors": [
            {
                "challengerId": "1001",
                "memberId": "2001",
                "name": "재원",
                "profileImageUrl": "https://cdn.umc.it/p/1001.png",
                "bestWorkbookPoint": 90
            }
        ],
        "members": [
            {
                "challengerId": "1002",
                "memberId": "2002",
                "name": "의재",
                "profileImageUrl": null,
                "bestWorkbookPoint": 80
            },
            {
                "challengerId": "1003",
                "memberId": "2003",
                "name": "민수",
                "profileImageUrl": "",
                "bestWorkbookPoint": null
            }
        ]
    }
    """
}

/// 멘토 1명만 담은 최소 JSON. `bestWorkbookPointField` 에는 `"bestWorkbookPoint": 90` 같은
/// 완성된 키-값 조각을 넣으며, 빈 문자열을 주면 키 자체가 빠진 응답(= 서버 현행)이 된다.
private func makeSingleMentorJSON(bestWorkbookPointField: String) -> String {
    let pointEntry = bestWorkbookPointField.isEmpty ? "" : ", \(bestWorkbookPointField)"
    return """
    {
        "groupId": "1", "name": "g", "part": "IOS",
        "createdAt": "2026-05-11T09:30:00Z", "memberCount": 1,
        "mentors": [
            { "challengerId": "1", "memberId": "2001", "name": "m"\(pointEntry) }
        ],
        "members": []
    }
    """
}

@Suite("StudyGroupDetailDTO — 디코딩/매핑")
struct StudyGroupDetailDTOTests {

    // MARK: - Decoding (happy path)

    @Test("전체 JSON 의 모든 필드를 정확히 디코딩한다")
    func decodesFullJSON() throws {
        let dto = try decodeDetail(makeFullDetailJSON())

        #expect(dto.groupId == "10")
        #expect(dto.name == "iOS 1팀")
        #expect(dto.part == "IOS")
        #expect(dto.partDisplayName == "iOS")
        #expect(dto.createdAt == "2026-05-11T09:30:00Z")
        #expect(dto.memberCount == 5)
        #expect(dto.schools.count == 1)
        #expect(dto.mentors.count == 1)
        #expect(dto.members.count == 2)
    }

    // MARK: - Decoding (server contract: number vs string IDs)

    @Test("groupId 가 JSON 숫자로 와도 String 으로 디코딩한다")
    func decodesGroupIdAsNumber() throws {
        let dto = try decodeDetail(makeFullDetailJSON(groupId: "10"))
        #expect(dto.groupId == "10")
    }

    @Test("groupId 가 JSON 문자열로 와도 동일한 String 으로 디코딩한다")
    func decodesGroupIdAsString() throws {
        let dto = try decodeDetail(makeFullDetailJSON(groupId: "\"10\""))
        #expect(dto.groupId == "10")
    }

    @Test("schoolId/logoImageId/challengerId/memberId 가 숫자로 와도 String 으로 디코딩한다")
    func decodesNestedIdsAsNumbers() throws {
        let json = """
        {
            "groupId": 10,
            "name": "g",
            "part": "IOS",
            "schools": [
                { "schoolId": 100, "schoolName": "s", "logoImageId": 200,
                  "totalStudyGroupCount": 1, "totalMemberCount": 2 }
            ],
            "createdAt": "2026-05-11T09:30:00Z",
            "memberCount": 1,
            "mentors": [
                { "challengerId": 1001, "memberId": 2001, "name": "m" }
            ],
            "members": []
        }
        """
        let dto = try decodeDetail(json)

        #expect(dto.schools.first?.schoolId == "100")
        #expect(dto.schools.first?.logoImageId == "200")
        #expect(dto.mentors.first?.challengerId == "1001")
        #expect(dto.mentors.first?.memberId == "2001")
    }

    // MARK: - Decoding (defaults / missing / null)

    @Test("거의 모든 필드가 없어도 기본값으로 안전하게 디코딩한다")
    func decodesWithDefaultsWhenFieldsMissing() throws {
        let dto = try decodeDetail("{}")

        #expect(dto.groupId == "")
        #expect(dto.name == "")
        #expect(dto.part == "")
        #expect(dto.partDisplayName == nil)
        #expect(dto.schools.isEmpty)
        #expect(dto.createdAt == "")
        #expect(dto.memberCount == 0)
        #expect(dto.mentors.isEmpty)
        #expect(dto.members.isEmpty)
    }

    @Test("partDisplayName 이 null 이면 nil 로 디코딩한다")
    func decodesNullPartDisplayNameAsNil() throws {
        let json = """
        { "groupId": "1", "name": "g", "part": "IOS", "partDisplayName": null,
          "createdAt": "2026-05-11T09:30:00Z", "memberCount": 0,
          "mentors": [], "members": [] }
        """
        let dto = try decodeDetail(json)
        #expect(dto.partDisplayName == nil)
    }

    @Test("mentors 키가 없고 legacy leader 단일 객체만 오면 mentors 배열로 흡수한다")
    func decodesLegacyLeaderIntoMentors() throws {
        let json = """
        {
            "groupId": "1",
            "name": "g",
            "part": "IOS",
            "createdAt": "2026-05-11T09:30:00Z",
            "memberCount": 1,
            "leader": { "challengerId": "1001", "memberId": "2001", "name": "리더" },
            "members": []
        }
        """
        let dto = try decodeDetail(json)

        #expect(dto.mentors.count == 1)
        #expect(dto.mentors.first?.name == "리더")
    }

    @Test("mentors 와 leader 모두 없으면 mentors 는 빈 배열이다")
    func decodesEmptyMentorsWhenNoMentorKeys() throws {
        let json = """
        { "groupId": "1", "name": "g", "part": "IOS",
          "createdAt": "2026-05-11T09:30:00Z", "memberCount": 0, "members": [] }
        """
        let dto = try decodeDetail(json)
        #expect(dto.mentors.isEmpty)
    }

    // MARK: - StudyGroupChallengerDTO bestWorkbookPoint

    @Test(
        "bestWorkbookPoint 는 숫자·숫자 String 을 Int 로 받고, null·키 부재는 nil 로 둔다",
        arguments: [
            ("\"bestWorkbookPoint\": 70", 70),
            ("\"bestWorkbookPoint\": \"70\"", 70),
            ("\"bestWorkbookPoint\": 0", 0),
            ("\"bestWorkbookPoint\": null", nil),
            ("", nil)
        ] as [(String, Int?)]
    )
    func decodesBestWorkbookPoint(field: String, expected: Int?) throws {
        let dto = try decodeDetail(makeSingleMentorJSON(bestWorkbookPointField: field))
        #expect(dto.mentors.first?.bestWorkbookPoint == expected)
    }

    // MARK: - Encodable round-trip (custom encode)

    @Test("custom encode 후 다시 디코딩하면 동일한 DTO 가 복원된다")
    func encodeRoundTripPreservesValues() throws {
        let original = try decodeDetail(makeFullDetailJSON())
        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(StudyGroupDetailDTO.self, from: encoded)

        #expect(restored == original)
    }

    // MARK: - toDomain (mapping)

    @Test("toDomain — serverID/name/createdDate 와 mentor/member 역할이 올바르게 매핑된다")
    func toDomainMapsCoreFields() throws {
        let dto = try decodeDetail(makeFullDetailJSON())
        let info = dto.toDomain()

        #expect(info.serverID == "10")
        #expect(info.name == "iOS 1팀")
        #expect(info.part == .front(type: .ios))
        #expect(info.mentors.count == 1)
        #expect(info.members.count == 2)
        #expect(info.mentors.first?.role == .leader)
        #expect(info.members.allSatisfy { $0.role == .member })
    }

    @Test(
        "toDomain — 알려진 part 문자열을 UMCPartType 으로 매핑한다",
        arguments: [
            ("\"IOS\"", UMCPartType.front(type: .ios)),
            ("\"ANDROID\"", UMCPartType.front(type: .android)),
            ("\"WEB\"", UMCPartType.front(type: .web)),
            ("\"SPRINGBOOT\"", UMCPartType.server(type: .spring)),
            ("\"PLAN\"", UMCPartType.pm),
            ("\"DESIGN\"", UMCPartType.design)
        ]
    )
    func toDomainMapsKnownPart(partJSON: String, expected: UMCPartType) throws {
        let dto = try decodeDetail(makeFullDetailJSON(part: partJSON))
        #expect(dto.toDomain().part == expected)
    }

    @Test("toDomain — 알 수 없는 part 문자열은 .front(.ios) 로 폴백한다")
    func toDomainFallsBackToIOSOnUnknownPart() throws {
        let dto = try decodeDetail(makeFullDetailJSON(part: "\"QUANTUM\""))
        #expect(dto.toDomain().part == .front(type: .ios))
    }

    @Test("toDomain — challengerID/memberID 가 String 으로 매핑되고 university 가 학교명으로 채워진다")
    func toDomainMapsIdsAndUniversity() throws {
        let dto = try decodeDetail(makeFullDetailJSON())
        let mentor = try #require(dto.toDomain().mentors.first)

        #expect(mentor.serverID == "2001")
        #expect(mentor.challengerID == "1001")
        #expect(mentor.memberID == "2001")
        #expect(mentor.university == "한성대학교")
        #expect(mentor.bestWorkbookPoint == 90)
    }

    @Test("toDomain — 빈 profileImageURL 은 nil 로, 유효한 URL 은 그대로 매핑한다")
    func toDomainNormalizesProfileImageURL() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.mentors.first?.profileImageURL == "https://cdn.umc.it/p/1001.png")
        // members[0]: profileImageUrl == null → nil
        #expect(info.members[0].profileImageURL == nil)
        // members[1]: profileImageUrl == "" → nil
        #expect(info.members[1].profileImageURL == nil)
    }

    @Test(
        "toDomain — bestWorkbookPoint 는 값이 있으면 그대로, null·키 부재면 0 으로 폴백한다",
        arguments: [
            ("\"bestWorkbookPoint\": 70", 70),
            ("\"bestWorkbookPoint\": \"70\"", 70),
            ("\"bestWorkbookPoint\": 0", 0),
            ("\"bestWorkbookPoint\": null", 0),
            ("", 0)
        ]
    )
    func toDomainResolvesBestWorkbookPoint(field: String, expected: Int) throws {
        let info = try decodeDetail(makeSingleMentorJSON(bestWorkbookPointField: field))
            .toDomain()
        #expect(info.mentors.first?.bestWorkbookPoint == expected)
    }

    /// 서버 계약 박제 — 스터디 그룹 응답(`StudyGroupMemberResponse`)에는 `bestWorkbookPoint`
    /// 필드가 없어 현행 응답에서는 전 멤버가 `0` 이 된다. 서버가 필드를 추가하면 이 테스트가
    /// 깨지는 게 아니라 위 파라미터화 테스트가 값 반영을 보장한다.
    @Test("toDomain — 서버 현행 응답처럼 필드가 전혀 없으면 모든 멤버가 0 이다")
    func toDomainYieldsZeroForEveryMemberWhenServerOmitsField() throws {
        let json = """
        {
            "groupId": "1", "name": "g", "part": "IOS",
            "createdAt": "2026-05-11T09:30:00Z", "memberCount": 3,
            "mentors": [ { "challengerId": "1", "memberId": "2001", "name": "멘토" } ],
            "members": [
                { "challengerId": "2", "memberId": "2002", "name": "챌린저1" },
                { "challengerId": "3", "memberId": "2003", "name": "챌린저2" }
            ]
        }
        """
        let info = try decodeDetail(json).toDomain()

        #expect(info.mentors.allSatisfy { $0.bestWorkbookPoint == 0 })
        #expect(info.members.allSatisfy { $0.bestWorkbookPoint == 0 })
    }

    @Test("toDomain — name 이 비어 있으면 defaultGroupName 으로 대체한다")
    func toDomainUsesDefaultGroupNameWhenNameEmpty() throws {
        let json = """
        { "groupId": "1", "name": "", "part": "IOS",
          "createdAt": "2026-05-11T09:30:00Z", "memberCount": 0,
          "mentors": [], "members": [] }
        """
        let info = try decodeDetail(json).toDomain(defaultGroupName: "기본 그룹명")
        #expect(info.name == "기본 그룹명")
    }

    // MARK: - toDomain (date parsing)

    @Test("toDomain — fractional seconds 가 없는 ISO8601 createdAt 을 파싱한다")
    func toDomainParsesISO8601WithoutFractionalSeconds() throws {
        let dto = try decodeDetail(makeFullDetailJSON(createdAt: "2026-05-11T09:30:00Z"))
        let expected = Date(timeIntervalSince1970: 1_778_491_800) // 2026-05-11T09:30:00Z
        #expect(dto.toDomain().createdDate == expected)
    }

    @Test("toDomain — fractional seconds 가 있는 ISO8601 createdAt 을 파싱한다")
    func toDomainParsesISO8601WithFractionalSeconds() throws {
        let dto = try decodeDetail(makeFullDetailJSON(createdAt: "2026-05-11T09:30:00.000Z"))
        let expected = Date(timeIntervalSince1970: 1_778_491_800)
        #expect(dto.toDomain().createdDate == expected)
    }
}
