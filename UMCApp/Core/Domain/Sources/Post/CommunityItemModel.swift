//
//  CommunityItemModel.swift
//  CoreDomain
//
//  Created by 김미주 on 5/10/26.
//

import Foundation
import CoreEnum

/// 커뮤니티 게시글 카드 모델
///
/// Community / MyPage 등 여러 Feature에서 공유합니다.
public struct CommunityItemModel: Equatable, Identifiable, Hashable {
    public let id = UUID()
    public let postId: Int
    public let userId: Int
    public let category: CommunityItemCategory
    public let title: String
    public let content: String
    public let profileImage: String?
    public let userName: String
    public let userNickname: String?
    public let part: UMCPartType
    public let createdAt: Date
    public var likeCount: Int
    public let commentCount: Int
    public var scrapCount: Int
    public var isLiked: Bool = false
    public var isScrapped: Bool = false
    public let isAuthor: Bool
    public let lightningInfo: CommunityLightningInfo?

    public var displayUserName: String {
        let trimmedNickname = userNickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != "알 수 없음" else { return "알 수 없음" }
        return trimmedNickname.isEmpty ? trimmedName : "\(trimmedNickname)/\(trimmedName)"
    }

    public init(
        postId: Int,
        userId: Int,
        category: CommunityItemCategory,
        title: String,
        content: String,
        profileImage: String?,
        userName: String,
        userNickname: String?,
        part: UMCPartType,
        createdAt: Date,
        likeCount: Int,
        commentCount: Int,
        scrapCount: Int,
        isLiked: Bool = false,
        isScrapped: Bool = false,
        isAuthor: Bool,
        lightningInfo: CommunityLightningInfo?
    ) {
        self.postId = postId
        self.userId = userId
        self.category = category
        self.title = title
        self.content = content
        self.profileImage = profileImage
        self.userName = userName
        self.userNickname = userNickname
        self.part = part
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.scrapCount = scrapCount
        self.isLiked = isLiked
        self.isScrapped = isScrapped
        self.isAuthor = isAuthor
        self.lightningInfo = lightningInfo
    }
}
