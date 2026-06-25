//
//  MyPagePostResponseDTOTests.swift
//  MyPageDataTests
//
//  toCommunityItemModel() / LightningInfoDTO.toDomain() / MyPagePostPageDTO.toDomain() 검증.
//

import Foundation
import Testing
import UMCFoundation
import CoreDomain
import MyPageDomain
@testable import MyPageData

@Suite("MyPagePostDTO — 도메인 변환 (toCommunityItemModel / Page.toDomain / LightningInfo.toDomain)")
struct MyPagePostResponseDTOTests {

    // MARK: - Fixtures

    private static func postDict(
        postId: String = "1",
        title: String = "제목",
        content: String = "본문",
        category: String = "FREE",
        authorId: String = "10",
        authorName: String = "작성자",
        authorPart: String = "IOS",
        createdAt: String = "2026-01-01T00:00:00Z",
        commentCount: String = "5",
        likeCount: String = "10",
        isLiked: Bool = false,
        isAuthor: Bool = false,
        authorProfileImage: String? = nil,
        lightning: [String: Any]? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "postId": postId,
            "title": title,
            "content": content,
            "category": category,
            "authorId": authorId,
            "authorName": authorName,
            "authorPart": authorPart,
            "createdAt": createdAt,
            "commentCount": commentCount,
            "likeCount": likeCount,
            "isLiked": isLiked,
            "isAuthor": isAuthor
        ]
        if let authorProfileImage { dict["authorProfileImage"] = authorProfileImage }
        if let lightning { dict["lightningInfo"] = lightning }
        return dict
    }

    private static func decodePost(_ dict: [String: Any]) throws -> MyPagePostResponseDTO {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(MyPagePostResponseDTO.self, from: data)
    }

    // MARK: - toCommunityItemModel

    @Test("필드들이 CommunityItemModel로 매핑된다 (String → Int 변환 포함)")
    func basicFieldsMapped() throws {
        let dto = try Self.decodePost(Self.postDict(
            postId: "42",
            authorId: "7",
            commentCount: "3",
            likeCount: "11"
        ))
        let item = dto.toCommunityItemModel()

        #expect(item.postId == "42")
        #expect(item.userId == "7")
        #expect(item.commentCount == 3)
        #expect(item.likeCount == 11)
        #expect(item.scrapCount == 0)
        #expect(item.userNickname == nil)
    }

    @Test(
        "category 문자열이 CommunityItemCategory로 매핑되고, 알 수 없는 값은 .free로 폴백한다",
        arguments: [
            ("LIGHTNING",   CommunityItemCategory.lighting),
            ("QUESTION",    .question),
            ("FREE",        .free),
            ("INFORMATION", .information),
            ("HABIT",       .habit),
            ("UNKNOWN",     .free)
        ]
    )
    func categoryMapping(raw: String, expected: CommunityItemCategory) throws {
        let dto = try Self.decodePost(Self.postDict(category: raw))
        let item = dto.toCommunityItemModel()

        #expect(item.category == expected)
    }

    @Test(
        "authorPart 문자열이 UMCPartType으로 디코딩된다",
        arguments: [
            ("ADMIN",      UMCPartType.admin),
            ("PLAN",       .pm),
            ("DESIGN",     .design)
        ]
    )
    func authorPartDecoded(raw: String, expected: UMCPartType) throws {
        let dto = try Self.decodePost(Self.postDict(authorPart: raw))
        let item = dto.toCommunityItemModel()

        #expect(item.part == expected)
    }

    @Test("createdAt UTC 문자열을 Date로 파싱한다")
    func createdAtParsedAsDate() throws {
        let dto = try Self.decodePost(Self.postDict(createdAt: "2026-01-01T00:00:00Z"))
        let item = dto.toCommunityItemModel()

        let expected = Date(timeIntervalSince1970: 1767225600) // 2026-01-01T00:00:00Z
        #expect(abs(item.createdAt.timeIntervalSince(expected)) < 1.0)
    }

    @Test("lightningInfo 누락 시 nil 처리")
    func lightningInfoNilWhenMissing() throws {
        let dto = try Self.decodePost(Self.postDict())
        let item = dto.toCommunityItemModel()

        #expect(item.lightningInfo == nil)
    }

    @Test("lightningInfo 존재 시 CommunityLightningInfo로 변환된다")
    func lightningInfoMapped() throws {
        let lightning: [String: Any] = [
            "meetAt": "2026-02-15T10:00:00Z",
            "location": "강남역",
            "maxParticipants": "8",
            "openChatUrl": "https://chat.example.com"
        ]
        let dto = try Self.decodePost(Self.postDict(lightning: lightning))
        let item = dto.toCommunityItemModel()

        #expect(item.lightningInfo?.location == "강남역")
        #expect(item.lightningInfo?.maxParticipants == 8)
        #expect(item.lightningInfo?.openChatUrl == "https://chat.example.com")
    }

    // MARK: - LightningInfoDTO.toDomain (JSON shape 흡수)

    @Test(
        "maxParticipants가 String이든 Number든 Int로 흡수된다",
        arguments: [
            #""8""#,
            "8"
        ]
    )
    func lightningMaxParticipantsFlexible(raw: String) throws {
        let json = """
        {
            "meetAt": "2026-02-15T10:00:00Z",
            "location": "L",
            "maxParticipants": \(raw),
            "openChatUrl": "https://x"
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(LightningInfoDTO.self, from: json)
        let domain = dto.toDomain()

        #expect(domain.maxParticipants == 8)
    }

    // MARK: - MyPagePostPageDTO.toDomain

    @Test("페이지 응답을 MyActivePostPage로 변환한다 (page String → Int)")
    func pageDtoToDomain() throws {
        let pageDict: [String: Any] = [
            "content": [
                Self.postDict(postId: "1"),
                Self.postDict(postId: "2")
            ],
            "page": "2",
            "size": "20",
            "totalElements": "40",
            "totalPages": "3",
            "hasNext": true,
            "hasPrevious": false
        ]
        let data = try JSONSerialization.data(withJSONObject: pageDict)
        let dto = try JSONDecoder().decode(
            MyPagePostPageDTO<MyPagePostResponseDTO>.self,
            from: data
        )

        let page = dto.toDomain()

        #expect(page.items.count == 2)
        #expect(page.items.first?.postId == "1")
        #expect(page.items.last?.postId == "2")
        #expect(page.page == 2)
        #expect(page.hasNext == true)
    }
}
