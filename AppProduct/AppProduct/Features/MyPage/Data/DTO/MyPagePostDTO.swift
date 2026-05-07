//
//  MyPagePostDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/15/26.
//

import Foundation

struct MyPagePostListQuery {
    let page: Int
    let size: Int
    let sort: [String]

    init(
        page: Int = 0,
        size: Int = 20,
        sort: [String] = ["createdAt,DESC"]
    ) {
        self.page = page
        self.size = size
        self.sort = sort
    }

    var toParameters: [String: Any] {
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

struct MyPagePostResponseDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postId = try container.decodeMyPageFlexibleString(forKey: .postId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        authorId = try container.decodeMyPageFlexibleString(forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorProfileImage = try container.decodeIfPresent(String.self, forKey: .authorProfileImage)
        authorPart = try container.decode(UMCPartType.self, forKey: .authorPart)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        commentCount = try container.decodeMyPageFlexibleString(forKey: .commentCount)
        likeCount = try container.decodeMyPageFlexibleString(forKey: .likeCount)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        isAuthor = try container.decode(Bool.self, forKey: .isAuthor)
        lightningInfo = try container.decodeIfPresent(LightningInfoDTO.self, forKey: .lightningInfo)
    }
}

struct MyPagePostPageDTO<T: Codable>: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode([T].self, forKey: .content)
        page = try container.decodeMyPageFlexibleString(forKey: .page)
        size = try container.decodeMyPageFlexibleString(forKey: .size)
        totalElements = try container.decodeMyPageFlexibleString(forKey: .totalElements)
        totalPages = try container.decodeMyPageFlexibleString(forKey: .totalPages)
        hasNext = try container.decode(Bool.self, forKey: .hasNext)
        hasPrevious = try container.decode(Bool.self, forKey: .hasPrevious)
    }
}
