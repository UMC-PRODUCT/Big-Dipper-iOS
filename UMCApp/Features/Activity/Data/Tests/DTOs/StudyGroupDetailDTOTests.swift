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

/// 서버 `StudyGroupResponse` 실제 키로 구성한 전체 응답 픽스처.
///
/// 키 이름(`studyGroupId`/`studyPart`/`memberName`/`schoolName`)은 실행 중인 서버의 OpenAPI
/// 스키마와 일치해야 한다. iOS 가 기대하는 이름으로 바꿔 쓰면 계약 어긋남을 테스트가 가려버린다.
private func makeFullDetailJSON(
    studyGroupId: String = "\"10\"",
    studyPart: String = "\"IOS\"",
    createdAt: String = "2026-05-11T09:30:00Z"
) -> String {
    """
    {
        "studyGroupId": \(studyGroupId),
        "name": "iOS 1팀",
        "gisuId": 7,
        "studyPart": \(studyPart),
        "createdAt": "\(createdAt)",
        "mentors": [
            {
                "memberId": "2001",
                "memberName": "재원",
                "schoolId": 100,
                "schoolName": "한성대학교",
                "profileImageUrl": "https://cdn.umc.it/p/1001.png"
            }
        ],
        "members": [
            {
                "memberId": "2002",
                "memberName": "의재",
                "schoolId": 100,
                "schoolName": "한성대학교",
                "profileImageUrl": null
            },
            {
                "memberId": "2003",
                "memberName": "민수",
                "schoolId": 200,
                "schoolName": "중앙대학교",
                "profileImageUrl": ""
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
        "studyGroupId": "1", "name": "g", "studyPart": "IOS",
        "createdAt": "2026-05-11T09:30:00Z",
        "mentors": [
            { "memberId": "2001", "memberName": "m", "schoolName": "한성대"\(pointEntry) }
        ],
        "members": []
    }
    """
}

@Suite("StudyGroupDetailDTO — 디코딩 매핑 (서버 contract)")
struct StudyGroupDetailDTOTests {

    // MARK: - Decoding (happy path)

    @Test("서버 실제 키로 구성한 전체 JSON 의 모든 필드를 디코딩한다")
    func decodesFullJSON() throws {
        let dto = try decodeDetail(makeFullDetailJSON())

        #expect(dto.studyGroupId == "10")
        #expect(dto.name == "iOS 1팀")
        #expect(dto.studyPart == "IOS")
        #expect(dto.createdAt == "2026-05-11T09:30:00Z")
        #expect(dto.mentors.count == 1)
        #expect(dto.members.count == 2)
    }

    // MARK: - Decoding (server contract: number vs string IDs)

    @Test(
        "studyGroupId 는 JSON 숫자로 와도 문자열로 와도 같은 String 이 된다",
        arguments: ["10", "\"10\""]
    )
    func decodesStudyGroupIdRegardlessOfJSONType(studyGroupIdJSON: String) throws {
        let dto = try decodeDetail(makeFullDetailJSON(studyGroupId: studyGroupIdJSON))
        #expect(dto.studyGroupId == "10")
    }

    @Test("memberId 가 숫자로 와도 String 으로 디코딩한다")
    func decodesMemberIdAsNumber() throws {
        let json = """
        {
            "studyGroupId": 10, "name": "g", "studyPart": "IOS",
            "createdAt": "2026-05-11T09:30:00Z",
            "mentors": [ { "memberId": 2001, "memberName": "m", "schoolName": "한성대" } ],
            "members": []
        }
        """
        let dto = try decodeDetail(json)
        #expect(dto.mentors.first?.memberId == "2001")
    }

    // MARK: - Decoding (defaults / missing / null)

    @Test("모든 필드가 없어도 기본값으로 안전하게 디코딩한다")
    func decodesWithDefaultsWhenFieldsMissing() throws {
        let dto = try decodeDetail("{}")

        #expect(dto.studyGroupId == "")
        #expect(dto.name == "")
        #expect(dto.studyPart == "")
        #expect(dto.createdAt == "")
        #expect(dto.mentors.isEmpty)
        #expect(dto.members.isEmpty)
    }

    // MARK: - allMemberIDs

    @Test("allMemberIDs — 멘토와 스터디원의 memberId 를 모두 모은다")
    func allMemberIDsCollectsMentorsAndMembers() throws {
        let ids = try decodeDetail(makeFullDetailJSON()).allMemberIDs
        #expect(Set(ids) == ["2001", "2002", "2003"])
    }

    @Test("allMemberIDs — 빈 memberId 는 조회 대상에서 제외한다")
    func allMemberIDsExcludesEmpty() throws {
        let json = """
        {
            "studyGroupId": "1", "name": "g", "studyPart": "IOS",
            "createdAt": "2026-05-11T09:30:00Z",
            "mentors": [ { "memberId": "", "memberName": "빈값" } ],
            "members": [ { "memberId": "2002", "memberName": "정상" } ]
        }
        """
        #expect(try decodeDetail(json).allMemberIDs == ["2002"])
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

    @Test("toDomain — serverID/name 과 mentor/member 역할이 올바르게 매핑된다")
    func toDomainMapsCoreFields() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.serverID == "10")
        #expect(info.name == "iOS 1팀")
        #expect(info.part == .front(type: .ios))
        #expect(info.mentors.count == 1)
        #expect(info.members.count == 2)
        #expect(info.mentors.first?.role == .leader)
        #expect(info.members.allSatisfy { $0.role == .member })
    }

    /// 서버 계약 회귀 방어 — `studyGroupId` 를 `groupId` 로 잘못 읽으면 `serverID` 가 빈 문자열이
    /// 되고, 그러면 운영진 화면이 모든 그룹을 "서버 미저장"으로 판정해 수정·삭제·멤버 변경이
    /// 통째로 막힌다. 키 이름이 다시 어긋나면 이 테스트가 먼저 깨진다.
    @Test("toDomain — serverID 가 비어 있지 않다 (CRUD 차단 회귀 방어)")
    func toDomainYieldsNonEmptyServerID() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(!info.serverID.isEmpty)
        #expect(info.serverID == "10")
    }

    @Test("toDomain — 멤버 이름은 서버 memberName 에서 채운다")
    func toDomainMapsMemberName() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.mentors.first?.name == "재원")
        #expect(info.members.map(\.name) == ["의재", "민수"])
    }

    /// 그룹 단위 대표 학교가 아니라 **멤버별** `schoolName` 을 쓴다 — 한 그룹에 여러 학교
    /// 멤버가 섞일 수 있어 그룹 대표값으로 뭉개면 틀린 학교가 표시된다.
    @Test("toDomain — university 는 멤버별 schoolName 에서 채운다")
    func toDomainMapsPerMemberSchoolName() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.mentors.first?.university == "한성대학교")
        #expect(info.members[0].university == "한성대학교")
        #expect(info.members[1].university == "중앙대학교")
    }

    @Test(
        "toDomain — 알려진 studyPart 문자열을 UMCPartType 으로 매핑한다",
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
        let dto = try decodeDetail(makeFullDetailJSON(studyPart: partJSON))
        #expect(dto.toDomain().part == expected)
    }

    @Test("toDomain — 알 수 없는 studyPart 문자열은 .front(.ios) 로 폴백한다")
    func toDomainFallsBackToIOSOnUnknownPart() throws {
        let dto = try decodeDetail(makeFullDetailJSON(studyPart: "\"QUANTUM\""))
        #expect(dto.toDomain().part == .front(type: .ios))
    }

    @Test("toDomain — memberID 가 String 으로 매핑된다")
    func toDomainMapsMemberID() throws {
        let mentor = try #require(decodeDetail(makeFullDetailJSON()).toDomain().mentors.first)

        #expect(mentor.serverID == "2001")
        #expect(mentor.memberID == "2001")
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

    /// 서버 계약 박제 — 스터디 그룹 응답에는 `bestWorkbookPoint` 필드가 없어 현행 응답에서는
    /// 전 멤버가 `0` 이 된다. 서버가 필드를 추가하면 위 파라미터화 테스트가 값 반영을 보장한다.
    @Test("toDomain — 서버 현행 응답처럼 필드가 전혀 없으면 모든 멤버가 0 이다")
    func toDomainYieldsZeroForEveryMemberWhenServerOmitsField() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.mentors.allSatisfy { $0.bestWorkbookPoint == 0 })
        #expect(info.members.allSatisfy { $0.bestWorkbookPoint == 0 })
    }

    @Test("toDomain — name 이 비어 있으면 defaultGroupName 으로 대체한다")
    func toDomainUsesDefaultGroupNameWhenNameEmpty() throws {
        let json = """
        {
            "studyGroupId": "1", "name": "", "studyPart": "IOS",
            "createdAt": "2026-05-11T09:30:00Z", "mentors": [], "members": []
        }
        """
        let info = try decodeDetail(json).toDomain(defaultGroupName: "기본 그룹명")
        #expect(info.name == "기본 그룹명")
    }

    // MARK: - toDomain (멤버 프로필 보강)

    @Test("toDomain — 보강 정보가 있으면 challengerID/nickname 을 채운다")
    func toDomainAppliesSupplement() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain(
            supplementsByMemberID: [
                "2001": StudyGroupMemberSupplement(challengerID: "C1", nickname: "재원닉")
            ]
        )
        let mentor = try #require(info.mentors.first)

        #expect(mentor.challengerID == "C1")
        #expect(mentor.nickname == "재원닉")
    }

    /// 보강은 멤버 단위로 독립적이다 — 일부만 해석돼도 나머지가 오염되면 안 된다.
    @Test("toDomain — 보강되지 않은 멤버는 challengerID/nickname 이 nil 로 남는다")
    func toDomainLeavesUnsupplementedMembersNil() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain(
            supplementsByMemberID: [
                "2002": StudyGroupMemberSupplement(challengerID: "C2", nickname: "의재닉")
            ]
        )

        #expect(info.members[0].challengerID == "C2")
        #expect(info.members[1].challengerID == nil)
        #expect(info.members[1].nickname == nil)
        #expect(info.mentors.first?.challengerID == nil)
    }

    /// `challengerId` 는 `memberId` 로 대체하지 않는다 — 서로 다른 식별자라 대체하면 잘못된
    /// 대상으로 서버를 호출하게 된다. 보강 실패 시에는 `nil` 이어야 한다.
    @Test("toDomain — 보강이 전혀 없으면 challengerID 는 memberId 로 대체되지 않는다")
    func toDomainDoesNotSubstituteMemberIDForChallengerID() throws {
        let info = try decodeDetail(makeFullDetailJSON()).toDomain()

        #expect(info.mentors.allSatisfy { $0.challengerID == nil })
        #expect(info.members.allSatisfy { $0.challengerID == nil })
    }

    @Test(
        "toDomain — 보강 값이 부분적으로만 있어도 있는 쪽만 채운다",
        arguments: [
            (StudyGroupMemberSupplement(challengerID: "C1", nickname: nil), "C1", nil),
            (StudyGroupMemberSupplement(challengerID: nil, nickname: "닉"), nil, "닉")
        ] as [(StudyGroupMemberSupplement, String?, String?)]
    )
    func toDomainAppliesPartialSupplement(
        supplement: StudyGroupMemberSupplement,
        expectedChallengerID: String?,
        expectedNickname: String?
    ) throws {
        let info = try decodeDetail(makeFullDetailJSON())
            .toDomain(supplementsByMemberID: ["2001": supplement])
        let mentor = try #require(info.mentors.first)

        #expect(mentor.challengerID == expectedChallengerID)
        #expect(mentor.nickname == expectedNickname)
    }

    // MARK: - toDomain (date parsing)

    @Test(
        "toDomain — fractional seconds 유무와 무관하게 ISO8601 createdAt 을 파싱한다",
        arguments: ["2026-05-11T09:30:00Z", "2026-05-11T09:30:00.000Z"]
    )
    func toDomainParsesISO8601(createdAt: String) throws {
        let dto = try decodeDetail(makeFullDetailJSON(createdAt: createdAt))
        let expected = Date(timeIntervalSince1970: 1_778_491_800) // 2026-05-11T09:30:00Z
        #expect(dto.toDomain().createdDate == expected)
    }
}
