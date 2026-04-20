//
//  MockCommunityRepositories.swift
//  AppProduct
//

import Foundation

// MARK: - MockCommunityRepository

/// 게스트 세션 및 프리뷰용 Community Repository Mock 구현체
final class MockCommunityRepository: CommunityRepositoryProtocol {

    func getSchools() async throws -> [String] {
        []
    }

    func getTrophies(query: TrophyListQuery) async throws -> [CommunityFameItemModel] {
        []
    }

    func getPosts(query: PostListQuery) async throws -> (
        items: [CommunityItemModel],
        hasNext: Bool
    ) {
        (items: [], hasNext: false)
    }

    func getSearch(query: PostSearchQuery) async throws -> (
        items: [CommunityItemModel],
        hasNext: Bool
    ) {
        (items: [], hasNext: false)
    }
}

// MARK: - MockCommunityPostRepository

/// 게스트 세션 및 프리뷰용 Community Post Repository Mock 구현체
final class MockCommunityPostRepository: CommunityPostRepositoryProtocol {

    func postPosts(request: PostRequestDTO) async throws {}

    func postLightning(request: CreateLightningPostRequestDTO) async throws {}

    func patchPosts(postId: Int, request: PostRequestDTO) async throws {}

    func patchLightning(postId: Int, request: CreateLightningPostRequestDTO) async throws {}
}

// MARK: - MockCommunityDetailRepository

/// 게스트 세션 및 프리뷰용 Community Detail Repository Mock 구현체
final class MockCommunityDetailRepository: CommunityDetailRepositoryProtocol {

    func deletePost(postId: Int) async throws {}

    func deleteComment(postId: Int, commentId: Int) async throws {}

    func getComments(postId: Int) async throws -> [CommunityCommentModel] {
        []
    }

    func getPostDetail(postId: Int) async throws -> CommunityItemModel {
        CommunityItemModel(
            postId: postId,
            userId: 1001,
            category: .free,
            title: "게스트 모드 게시글",
            content: "게스트 모드에서 표시되는 Mock 게시글입니다.",
            profileImage: nil,
            userName: "홍길동",
            userNickname: "길동이",
            part: .front(type: .ios),
            createdAt: Date(),
            likeCount: 0,
            commentCount: 0,
            scrapCount: 0,
            isLiked: false,
            isAuthor: false,
            lightningInfo: nil
        )
    }

    func postScrap(postId: Int) async throws {}

    func postLike(postId: Int) async throws {}

    func postComment(postId: Int, request: PostCommentRequest) async throws {}

    func postPostReport(postId: Int) async throws {}

    func postCommentReport(commentId: Int) async throws {}
}
