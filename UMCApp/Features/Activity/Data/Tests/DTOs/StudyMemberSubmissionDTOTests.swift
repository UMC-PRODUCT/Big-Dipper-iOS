//
//  StudyMemberSubmissionDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

#if DEBUG

// MARK: - Helpers

private func decodeRow(_ json: String) throws -> StudyMemberSubmissionDTO {
    try JSONDecoder().decode(StudyMemberSubmissionDTO.self, from: Data(json.utf8))
}

private func decodeWeek(_ json: String) throws -> WeeklySubmissionDTO {
    try JSONDecoder().decode(WeeklySubmissionDTO.self, from: Data(json.utf8))
}

private func decodePage(_ json: String) throws -> StudyMemberSubmissionPageDTO {
    try JSONDecoder().decode(StudyMemberSubmissionPageDTO.self, from: Data(json.utf8))
}

/// 스터디원 행 JSON. `part` 만 바꿔 파트 매핑 경로를 검증한다(나머지 값은 결과와 무관).
private func makeRowJSON(part: String) -> String {
    """
    {
      "studyGroupMemberId": 11, "memberId": 101, "memberName": "박철수",
      "studyGroupId": 3, "studyGroupName": "iOS A팀",
      "part": "\(part)", "weeks": []
    }
    """
}

// MARK: - 식별자 타입 통일

@Suite("StudyMemberSubmissionDTO — 서버 응답 디코딩 (서버 contract)")
struct StudyMemberSubmissionDTOTests {

    @Test("서버가 식별자를 정수로 내려도 String 으로 디코딩된다")
    func decodesNumericIdentifiersAsString() throws {
        let dto = try decodeRow(
            """
            {
              "studyGroupMemberId": 11, "memberId": 101, "memberName": "박철수",
              "studyGroupId": 3, "studyGroupName": "iOS A팀", "part": "IOS", "weeks": []
            }
            """
        )

        #expect(dto.studyGroupMemberId == "11")
        #expect(dto.memberId == "101")
        #expect(dto.studyGroupId == "3")
    }

    @Test("서버가 식별자를 문자열로 내려도 같은 값으로 디코딩된다")
    func decodesStringIdentifiersUnchanged() throws {
        let dto = try decodeRow(
            """
            {
              "studyGroupMemberId": "11", "memberId": "101", "memberName": "박철수",
              "studyGroupId": "3", "studyGroupName": "iOS A팀", "part": "IOS", "weeks": []
            }
            """
        )

        #expect(dto.studyGroupMemberId == "11")
        #expect(dto.memberId == "101")
        #expect(dto.studyGroupId == "3")
    }

    @Test("선택 필드가 null 이면 nil 로 디코딩된다")
    func decodesOptionalNullsAsNil() throws {
        let dto = try decodeRow(
            """
            {
              "studyGroupMemberId": 11, "memberId": 101, "memberName": "이영희",
              "nickname": null, "schoolName": null, "profileImageUrl": null,
              "studyGroupId": 3, "studyGroupName": "iOS A팀", "part": "IOS", "weeks": []
            }
            """
        )

        #expect(dto.nickname == nil)
        #expect(dto.schoolName == nil)
        #expect(dto.profileImageURL == nil)
    }

    // MARK: - 파트 매핑

    @Test(
        "서버 파트 원문은 UMCPartType 으로 해석되고 라벨은 표시 이름이 된다",
        arguments: [
            ("IOS", UMCPartType.front(type: .ios), "iOS"),
            ("SPRINGBOOT", .server(type: .spring), "Spring"),
            ("PLAN", .pm, "PM")
        ]
    )
    func mapsServerPartToPartType(
        raw: String,
        expectedPart: UMCPartType,
        expectedLabel: String
    ) throws {
        let domain = try decodeRow(makeRowJSON(part: raw)).toDomain()

        #expect(domain.part == expectedPart)
        #expect(domain.partLabel == expectedLabel)
    }

    @Test("모르는 파트는 nil 로 두되 서버 원문을 라벨로 보존한다")
    func preservesUnknownPartLabel() throws {
        let domain = try decodeRow(makeRowJSON(part: "QUANTUM")).toDomain()

        #expect(domain.part == nil)
        #expect(domain.partLabel == "QUANTUM")
    }
}

// MARK: - 주차 디코딩

@Suite("WeeklySubmissionDTO — 주차 제출 현황 디코딩 (서버 contract)")
struct WeeklySubmissionDTOTests {

    @Test("워크북이 배포된 주차는 식별자와 상태를 그대로 매핑한다")
    func decodesDistributedWeek() throws {
        let dto = try decodeWeek(
            """
            {
              "weekNo": 1, "weeklyCurriculumId": 21,
              "challengerWorkbookId": 31, "status": "PASS", "isBest": true
            }
            """
        )

        #expect(dto.weekNo == "1")
        #expect(dto.weeklyCurriculumId == "21")
        #expect(dto.challengerWorkbookId == "31")
        #expect(dto.status == .pass)
        #expect(dto.isBest)
    }

    @Test("challengerWorkbookId 가 null 이면 nil + NOT_SUBMITTED 로 매핑된다 (미배포 인원)")
    func decodesNotDistributedWeek() throws {
        let dto = try decodeWeek(
            """
            {
              "weekNo": 2, "weeklyCurriculumId": 22,
              "challengerWorkbookId": null, "status": "NOT_SUBMITTED", "isBest": false
            }
            """
        )

        #expect(dto.challengerWorkbookId == nil)
        #expect(dto.status == .notSubmitted)
    }

    @Test("challengerWorkbookId 키 자체가 없어도 nil 로 흡수한다")
    func decodesMissingWorkbookKey() throws {
        let dto = try decodeWeek(
            """
            { "weekNo": 2, "weeklyCurriculumId": 22, "status": "NOT_SUBMITTED" }
            """
        )

        #expect(dto.challengerWorkbookId == nil)
        #expect(!dto.isBest)
    }

    @Test("모르는 상태 값은 .unknown 으로 흡수해 페이지 전체 디코딩을 깨뜨리지 않는다")
    func decodesUnknownStatus() throws {
        let dto = try decodeWeek(
            """
            {
              "weekNo": 1, "weeklyCurriculumId": 21,
              "challengerWorkbookId": 31, "status": "SUBMITTED", "isBest": false
            }
            """
        )

        #expect(dto.status == .unknown)
    }

    @Test("isBest 는 상태와 독립이라 PASS 이면서 베스트일 수 있다")
    func isBestIsIndependentOfStatus() throws {
        let dto = try decodeWeek(
            """
            {
              "weekNo": 1, "weeklyCurriculumId": 21,
              "challengerWorkbookId": 31, "status": "PASS", "isBest": true
            }
            """
        )

        #expect(dto.status == .pass)
        #expect(dto.isBest)
    }
}

// MARK: - 페이지 디코딩

@Suite("StudyMemberSubmissionPageDTO — 커서 페이지 디코딩 (서버 contract)")
struct StudyMemberSubmissionPageDTOTests {

    @Test("커서가 정수로 와도 String 으로 통일된다")
    func decodesNumericCursorAsString() throws {
        let dto = try decodePage(
            """
            { "content": [], "nextCursor": 12, "hasNext": true }
            """
        )

        #expect(dto.nextCursor == "12")
        #expect(dto.hasNext)
    }

    @Test("마지막 페이지는 nextCursor 가 nil, hasNext 가 false 로 온다")
    func decodesLastPage() throws {
        let dto = try decodePage(
            """
            { "content": [], "nextCursor": null, "hasNext": false }
            """
        )

        #expect(dto.nextCursor == nil)
        #expect(!dto.hasNext)
    }

    @Test("content 키가 없으면 빈 배열로 흡수한다")
    func decodesMissingContentAsEmpty() throws {
        let dto = try decodePage(#"{ "hasNext": false }"#)

        #expect(dto.content.isEmpty)
        #expect(dto.toDomain().content.isEmpty)
    }
}

// MARK: - 그룹 이름 목록

@Suite("StudyGroupNamesDTO — 그룹 이름 목록 디코딩 (서버 contract)")
struct StudyGroupNamesDTOTests {

    @Test("groupId 는 정수/문자열 어느 쪽으로 와도 String 으로 통일된다")
    func decodesGroupIdAsString() throws {
        let dto = try JSONDecoder().decode(
            StudyGroupNamesDTO.self,
            from: Data(
                """
                {
                  "studyGroups": [
                    { "groupId": 3, "name": "iOS A팀" },
                    { "groupId": "4", "name": "iOS B팀" }
                  ]
                }
                """.utf8
            )
        )

        #expect(dto.toDomain().map(\.groupId) == ["3", "4"])
    }

    @Test("studyGroups 키가 없으면 빈 목록으로 흡수한다")
    func decodesMissingListAsEmpty() throws {
        let dto = try JSONDecoder().decode(
            StudyGroupNamesDTO.self,
            from: Data("{}".utf8)
        )

        #expect(dto.toDomain().isEmpty)
    }
}

#endif
