//
//  CommunityPostResponseDTO.swift
//  AppProduct
//
//  Created by 김미주 on 2/14/26.
//

import Foundation

// MARK: - 1. 공통 게시글 DTO (상세 조회용)
struct PostDetailDTO: Codable {
    let postId: String
    let title: String
    let content: String
    let category: String
    let authorId: String?
    let authorChallengerId: String?
    let authorMemberId: String?
    let authorName: String?
    let authorNickname: String?
    let challengerNickname: String?
    let authorProfileImage: String?
    let authorPart: String?
    let lightningInfo: LightningInfoDTO?
    let commentCount: String
    let writeTime: String
    let likeCount: String
    let isLiked: Bool
    let isAuthor: Bool?
    let scrapCount: String
    let isScrapped: Bool

    private enum CodingKeys: String, CodingKey {
        case postId
        case title
        case content
        case category
        case authorId
        case authorChallengerId
        case authorMemberId
        case authorName
        case authorNickname
        case challengerNickname
        case authorProfileImage
        case authorPart
        case lightningInfo
        case commentCount
        case writeTime
        case likeCount
        case isLiked
        case isAuthor
        case scrapCount
        case isScrapped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postId = try container.decodeFlexibleString(forKey: .postId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        authorId = container.decodeFlexibleOptionalString(forKey: .authorId)
        authorChallengerId = container.decodeFlexibleOptionalString(forKey: .authorChallengerId)
        authorMemberId = container.decodeFlexibleOptionalString(forKey: .authorMemberId)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        authorNickname = container.decodeFirstNonEmptyString(
            forKeys: [.authorNickname, .challengerNickname]
        )
        challengerNickname = try container.decodeIfPresent(String.self, forKey: .challengerNickname)
        authorProfileImage = try container.decodeIfPresent(String.self, forKey: .authorProfileImage)
        authorPart = try container.decodeIfPresent(String.self, forKey: .authorPart)
        lightningInfo = try container.decodeIfPresent(LightningInfoDTO.self, forKey: .lightningInfo)
        commentCount = try container.decodeFlexibleString(forKey: .commentCount)
        writeTime = try container.decode(String.self, forKey: .writeTime)
        likeCount = try container.decodeFlexibleString(forKey: .likeCount)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        isAuthor = try container.decodeIfPresent(Bool.self, forKey: .isAuthor)
        scrapCount = try container.decodeFlexibleString(forKey: .scrapCount)
        isScrapped = try container.decode(Bool.self, forKey: .isScrapped)
    }
}

// MARK: - 2. 리스트 내 개별 항목 DTO
struct PostListItemDTO: Codable {
    let postId: String
    let title: String
    let content: String
    let category: String
    let authorId: String?
    let authorChallengerId: String?
    let authorMemberId: String?
    let authorName: String?
    let authorNickname: String?
    let challengerNickname: String?
    let authorProfileImage: String?
    let authorPart: String?
    let createdAt: String
    let commentCount: String
    let likeCount: String
    let isLiked: Bool
    let isAuthor: Bool?
    let lightningInfo: LightningInfoDTO?

    private enum CodingKeys: String, CodingKey {
        case postId
        case title
        case content
        case category
        case authorId
        case authorChallengerId
        case authorMemberId
        case authorName
        case authorNickname
        case challengerNickname
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
        postId = try container.decodeFlexibleString(forKey: .postId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(String.self, forKey: .category)
        authorId = container.decodeFlexibleOptionalString(forKey: .authorId)
        authorChallengerId = container.decodeFlexibleOptionalString(forKey: .authorChallengerId)
        authorMemberId = container.decodeFlexibleOptionalString(forKey: .authorMemberId)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        authorNickname = container.decodeFirstNonEmptyString(
            forKeys: [.authorNickname, .challengerNickname]
        )
        challengerNickname = try container.decodeIfPresent(String.self, forKey: .challengerNickname)
        authorProfileImage = try container.decodeIfPresent(String.self, forKey: .authorProfileImage)
        authorPart = try container.decodeIfPresent(String.self, forKey: .authorPart)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        commentCount = try container.decodeFlexibleString(forKey: .commentCount)
        likeCount = try container.decodeFlexibleString(forKey: .likeCount)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        isAuthor = try container.decodeIfPresent(Bool.self, forKey: .isAuthor) ?? false
        lightningInfo = try container.decodeIfPresent(LightningInfoDTO.self, forKey: .lightningInfo)
    }
}

// MARK: - 3. 공통 번개 정보
struct LightningInfoDTO: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meetAt = try container.decode(String.self, forKey: .meetAt)
        location = try container.decode(String.self, forKey: .location)
        openChatUrl = try container.decode(String.self, forKey: .openChatUrl)

        if let stringValue = try? container.decode(String.self, forKey: .maxParticipants) {
            maxParticipants = stringValue
        } else if let intValue = try? container.decode(Int.self, forKey: .maxParticipants) {
            maxParticipants = String(intValue)
        } else {
            maxParticipants = "0"
        }
    }
    
    func toModel() -> CommunityLightningInfo {
        return CommunityLightningInfo(
            meetAt: ServerDateTimeConverter.parseUTCDateTime(meetAt) ?? Date(),
            location: location,
            maxParticipants: Int(maxParticipants) ?? 0,
            openChatUrl: openChatUrl
        )
    }
}

// 리스트 항목 변환
extension PostListItemDTO {
    func toCommunityItemModel() -> CommunityItemModel {
        let resolvedAuthorName = resolvedDisplayName(authorName: authorName)

        return CommunityItemModel(
            postId: Int(postId) ?? 0,
            userId: authorId.flatMap(Int.init) ?? 0,
            category: CommunityItemCategory(apiValue: category) ?? .free,
            title: title,
            content: content,
            profileImage: authorProfileImage,
            userName: resolvedAuthorName,
            userNickname: authorNickname,
            part: UMCPartType(apiValue: authorPart ?? "PM") ?? .pm,
            createdAt: ServerDateTimeConverter.parseUTCDateTime(createdAt) ?? Date(),
            likeCount: Int(likeCount) ?? 0,
            commentCount: Int(commentCount) ?? 0,
            scrapCount: 0,
            isLiked: isLiked,
            isAuthor: isAuthor ?? false,
            lightningInfo: lightningInfo?.toModel(),
        )
    }
}

// 상세 정보 변환
extension PostDetailDTO {
    func toCommunityItemModel() -> CommunityItemModel {
        let resolvedAuthorName = resolvedDisplayName(authorName: authorName)

        return CommunityItemModel(
            postId: Int(postId) ?? 0,
            userId: authorId.flatMap(Int.init) ?? 0,
            category: CommunityItemCategory(apiValue: category) ?? .free,
            title: title,
            content: content,
            profileImage: authorProfileImage,
            userName: resolvedAuthorName,
            userNickname: authorNickname,
            part: UMCPartType(apiValue: authorPart ?? "PM") ?? .pm,
            createdAt: ServerDateTimeConverter.parseUTCDateTime(writeTime) ?? Date(),
            likeCount: Int(likeCount) ?? 0,
            commentCount: Int(commentCount) ?? 0,
            scrapCount: Int(scrapCount) ?? 0,
            isLiked: isLiked,
            isScrapped: isScrapped,
            isAuthor: isAuthor ?? false ,
            lightningInfo: lightningInfo?.toModel()
        )
    }
}

// MARK: - 좋아요/스크랩
struct CommunityLikeDTO: Codable {
    let liked: Bool
    let likeCount: String
}

struct CommunityScrapDTO: Codable {
    let scrapped: Bool
    let scrapCount: String
}

// MARK: - Helper

private func resolvedDisplayName(authorName: String?) -> String {
    let trimmedAuthorName = authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !trimmedAuthorName.isEmpty else {
        return "알 수 없음"
    }

    return trimmedAuthorName
}

private extension KeyedDecodingContainer {
    func decodeFirstNonEmptyString(forKeys keys: [Key]) -> String? {
        keys
            .compactMap { try? decodeIfPresent(String.self, forKey: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected String/Int/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        return nil
    }
}
