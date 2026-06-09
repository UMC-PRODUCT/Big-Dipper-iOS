//
//  NoticeListDecodeTests.swift
//  AppProductTests
//
//  홈 최근 공지 리스트 응답(NoticeListResponseDTO) 디코드 회귀 검증.
//  TargetInfoDTO.targetNoticeTab 을 non-optional 로 전환한 뒤에도
//  서버 응답이 키를 주든 빠뜨리든 크래시 없이 디코드되는지 고정한다.
//

@testable import AppProduct
import Foundation
import Testing

// MARK: - Helpers

/// `NoticeListResponseDTO` 의 `Codable` 채택이 main-actor 격리
/// (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor)라서 디코딩을 메인 액터에서 수행한다.
@MainActor
private func decodeNoticeList(_ json: String) throws -> NoticeListResponseDTO {
    let data = try #require(json.data(using: .utf8))
    return try JSONDecoder().decode(NoticeListResponseDTO.self, from: data)
}

/// 서버 응답 형태(숫자는 String 직렬화)의 단일 공지 JSON.
/// `targetInfoBody` 로 targetInfo 영역만 갈아끼워 케이스별 회귀를 만든다.
private func makeNoticeJSON(targetInfoBody: String) -> String {
    """
    {
        "id": "101",
        "noticeId": "101",
        "title": "공지 제목",
        "content": "공지 내용",
        "shouldSendNotification": true,
        "viewCount": "42",
        "createdAt": "2026-06-09T12:00:00.000Z",
        "targetInfo": \(targetInfoBody),
        "authorChallengerId": "7",
        "authorNickname": "닉네임",
        "authorName": "이름"
    }
    """
}

// MARK: - Tests

@Suite("NoticeListResponseDTO — 홈 리스트 디코드 회귀 (도메인 규칙)")
@MainActor
struct NoticeListDecodeTests {

    @Test("targetNoticeTab 키가 있으면 값이 그대로 보존된다")
    func decodesPresentTargetNoticeTab() throws {
        let json = makeNoticeJSON(targetInfoBody: """
        {
            "targetGisuId": "14",
            "targetChapterId": null,
            "targetSchoolId": "3",
            "targetParts": null,
            "targetNoticeTab": "SCHOOL_CORE"
        }
        """)

        let dto = try decodeNoticeList(json)

        #expect(dto.targetInfo.targetNoticeTab == "SCHOOL_CORE")
        #expect(dto.targetInfo.targetGisuId == 14)
        #expect(dto.targetInfo.targetSchoolId == 3)
    }

    @Test("targetNoticeTab 키가 없으면 CHALLENGER 로 폴백한다 (서버 생략 방어)")
    func decodesMissingTargetNoticeTabAsChallenger() throws {
        let json = makeNoticeJSON(targetInfoBody: """
        {
            "targetGisuId": "14",
            "targetChapterId": null,
            "targetSchoolId": null,
            "targetParts": null
        }
        """)

        let dto = try decodeNoticeList(json)

        #expect(dto.targetInfo.targetNoticeTab == "CHALLENGER")
    }

    @Test("targetNoticeTab 이 null 이어도 CHALLENGER 로 폴백한다")
    func decodesNullTargetNoticeTabAsChallenger() throws {
        let json = makeNoticeJSON(targetInfoBody: """
        {
            "targetGisuId": "14",
            "targetChapterId": null,
            "targetSchoolId": null,
            "targetParts": null,
            "targetNoticeTab": null
        }
        """)

        let dto = try decodeNoticeList(json)

        #expect(dto.targetInfo.targetNoticeTab == "CHALLENGER")
    }

    @Test("targetInfo 자체가 null 이면 폴백 TargetInfoDTO 가 동작한다")
    func decodesNullTargetInfoWithFallback() throws {
        let json = makeNoticeJSON(targetInfoBody: "null")

        let dto = try decodeNoticeList(json)

        // init(from:) 의 폴백 TargetInfoDTO(targetNoticeTab: CHALLENGER) 경로.
        #expect(dto.targetInfo.targetGisuId == 0)
        #expect(dto.targetInfo.targetNoticeTab == "CHALLENGER")
    }

    @Test("targetInfo 키 자체가 없어도 폴백 TargetInfoDTO 가 동작한다")
    func decodesMissingTargetInfoWithFallback() throws {
        let json = """
        {
            "id": "101",
            "noticeId": "101",
            "title": "공지 제목",
            "content": "공지 내용",
            "shouldSendNotification": true,
            "viewCount": "42",
            "createdAt": "2026-06-09T12:00:00.000Z",
            "authorChallengerId": "7",
            "authorNickname": "닉네임",
            "authorName": "이름"
        }
        """

        let dto = try decodeNoticeList(json)

        #expect(dto.targetInfo.targetNoticeTab == "CHALLENGER")
    }

    @Test("운영진 응답의 targetParts(apiValue 배열)도 정상 디코드된다")
    func decodesManagementTargetParts() throws {
        let json = makeNoticeJSON(targetInfoBody: """
        {
            "targetGisuId": "14",
            "targetChapterId": null,
            "targetSchoolId": "3",
            "targetParts": ["IOS", "SPRINGBOOT"],
            "targetNoticeTab": "SCHOOL_PART_LEADER"
        }
        """)

        let dto = try decodeNoticeList(json)

        #expect(dto.targetInfo.targetNoticeTab == "SCHOOL_PART_LEADER")
        #expect(dto.targetInfo.targetParts == [.front(type: .ios), .server(type: .spring)])
    }
}
