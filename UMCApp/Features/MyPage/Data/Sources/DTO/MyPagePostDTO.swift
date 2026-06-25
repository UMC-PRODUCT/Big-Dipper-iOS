//
//  MyPagePostDTO.swift
//  MyPageData
//
//  마이페이지 게시글 목록(작성/좋아요/스크랩) 조회 관련 DTO 모음.
//  - Query / Response Item / Response Page / Nested(LightningInfo) DTO를 한 파일에 모은다.
//

import Foundation
import UMCFoundation
import CoreDomain
import MyPageDomain

// MARK: - Query

/// 마이페이지 게시글 목록 조회 쿼리 DTO
///
/// Domain의 `MyPagePostListQuery`를 받아 URL 쿼리 파라미터(`toParameters`)로
/// 직렬화하는 책임을 갖습니다. `GET /api/v1/posts/my|commented|scrapped` 의
/// `?page=&size=&sort=` 쿼리스트링에 사용됩니다.
public struct MyPagePostListQueryDTO: Encodable {
    public let page: Int
    public let size: Int
    public let sort: [String]

    public init(query: MyPagePostListQuery) {
        self.page = query.page
        self.size = query.size
        self.sort = query.sort
    }

    public var toParameters: [String: Any] {
        var params: [String: Any] = [
            "page": page,
            "size": size
        ]
        if !sort.isEmpty {
            params["sort"] = sort
        }
        return params
    }
}

// MARK: - Response Item

/// 마이페이지 게시글 항목 응답 DTO
///
/// 다음 엔드포인트가 동일한 페이지 응답 형태로 내려주는 `content[]` 항목입니다.
/// - `GET /api/v1/posts/my` — 내가 쓴 글
/// - `GET /api/v1/posts/commented` — 댓글 단 글
/// - `GET /api/v1/posts/scrapped` — 스크랩한 글
///
/// `userNickname`/`scrapCount`는 응답에 포함되지 않아 도메인 변환 시 `nil` / `0`으로 채웁니다.
public struct MyPagePostResponseDTO: Codable {
    let postId: String
    let title: String
    let content: String
    let category: String
    let authorId: String
    let authorName: String
    let authorProfileImage: String?
    let authorPart: UMCPartType
    let createdAt: String
    let commentCount: String
    let likeCount: String
    let isLiked: Bool
    let isAuthor: Bool
    let lightningInfo: LightningInfoDTO?

    private enum CodingKeys: String, CodingKey {
        case postId
        case title
        case content
        case category
        case authorId
        case authorName
        case authorProfileImage
        case authorPart
        case createdAt
        case commentCount
        case likeCount
        case isLiked
        case isAuthor
        case lightningInfo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postId = try container.decodeFlexibleString(forKey: .postId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        authorId = try container.decodeFlexibleString(forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorProfileImage = try container.decodeIfPresent(String.self, forKey: .authorProfileImage)
        authorPart = try container.decode(UMCPartType.self, forKey: .authorPart)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        commentCount = try container.decodeFlexibleString(forKey: .commentCount)
        likeCount = try container.decodeFlexibleString(forKey: .likeCount)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        isAuthor = try container.decode(Bool.self, forKey: .isAuthor)
        lightningInfo = try container.decodeIfPresent(LightningInfoDTO.self, forKey: .lightningInfo)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postId, forKey: .postId)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(category, forKey: .category)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encodeIfPresent(authorProfileImage, forKey: .authorProfileImage)
        try container.encode(authorPart, forKey: .authorPart)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(isLiked, forKey: .isLiked)
        try container.encode(isAuthor, forKey: .isAuthor)
        try container.encodeIfPresent(lightningInfo, forKey: .lightningInfo)
    }
}

public extension MyPagePostResponseDTO {
    /// 마이페이지 게시글 응답을 공용 `CommunityItemModel` 도메인으로 변환합니다.
    func toCommunityItemModel() -> CommunityItemModel {
        let parsedCreatedAt = ServerDateTimeConverter.parseUTCDateTime(createdAt) ?? Date()

        return CommunityItemModel(
            postId: postId,
            userId: authorId,
            category: CommunityItemCategory(apiValue: category) ?? .free,
            title: title,
            content: content,
            profileImage: authorProfileImage,
            userName: authorName,
            userNickname: nil,
            part: authorPart,
            createdAt: parsedCreatedAt,
            likeCount: Int(likeCount) ?? 0,
            commentCount: Int(commentCount) ?? 0,
            scrapCount: 0,
            isLiked: isLiked,
            isAuthor: isAuthor,
            lightningInfo: lightningInfo?.toDomain()
        )
    }
}

// MARK: - Response Page

/// Spring Pageable 형식의 공통 페이지 응답 DTO
///
/// `content` 배열을 제외한 페이지 메타(`page`/`size`/`totalElements`/`totalPages`)는
/// 서버가 정수를 String으로 직렬화하므로 모두 `String`으로 보존합니다.
///
/// - Note: 마이페이지 게시글 페이지 응답은 `MyPagePostPageDTO<MyPagePostResponseDTO>` 로 사용합니다.
public struct MyPagePostPageDTO<T: Codable>: Codable {
    let content: [T]
    let page: String
    let size: String
    let totalElements: String
    let totalPages: String
    let hasNext: Bool
    let hasPrevious: Bool

    private enum CodingKeys: String, CodingKey {
        case content
        case page
        case size
        case totalElements
        case totalPages
        case hasNext
        case hasPrevious
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode([T].self, forKey: .content)
        page = try container.decodeFlexibleString(forKey: .page)
        size = try container.decodeFlexibleString(forKey: .size)
        totalElements = try container.decodeFlexibleString(forKey: .totalElements)
        totalPages = try container.decodeFlexibleString(forKey: .totalPages)
        hasNext = try container.decode(Bool.self, forKey: .hasNext)
        hasPrevious = try container.decode(Bool.self, forKey: .hasPrevious)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(page, forKey: .page)
        try container.encode(size, forKey: .size)
        try container.encode(totalElements, forKey: .totalElements)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(hasNext, forKey: .hasNext)
        try container.encode(hasPrevious, forKey: .hasPrevious)
    }
}

public extension MyPagePostPageDTO where T == MyPagePostResponseDTO {
    /// 페이지 응답을 마이페이지 도메인 모델로 변환합니다.
    func toDomain() -> MyActivePostPage {
        MyActivePostPage(
            items: content.map { $0.toCommunityItemModel() },
            page: Int(page) ?? 0,
            hasNext: hasNext
        )
    }
}

// MARK: - Nested DTO (LightningInfo)

/// 마이페이지 게시글 응답 안의 번개(Lightning) 정보 DTO
///
/// DTO는 Feature 간 공유하지 않습니다. Community Feature는 별도로 자기 LightningInfoDTO를 가집니다.
/// 도메인 모델(`CommunityLightningInfo`)만 `CoreDomain`에서 공유합니다.
public struct LightningInfoDTO: Codable {
    let meetAt: String
    let location: String
    let maxParticipants: String
    let openChatUrl: String

    private enum CodingKeys: String, CodingKey {
        case meetAt
        case location
        case maxParticipants
        case openChatUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meetAt = try container.decode(String.self, forKey: .meetAt)
        location = try container.decode(String.self, forKey: .location)
        openChatUrl = try container.decode(String.self, forKey: .openChatUrl)
        maxParticipants = try container.decodeFlexibleString(forKey: .maxParticipants)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(meetAt, forKey: .meetAt)
        try container.encode(location, forKey: .location)
        try container.encode(maxParticipants, forKey: .maxParticipants)
        try container.encode(openChatUrl, forKey: .openChatUrl)
    }

    public func toDomain() -> CommunityLightningInfo {
        CommunityLightningInfo(
            meetAt: ServerDateTimeConverter.parseUTCDateTime(meetAt) ?? Date(),
            location: location,
            maxParticipants: Int(maxParticipants) ?? 0,
            openChatUrl: openChatUrl
        )
    }
}
