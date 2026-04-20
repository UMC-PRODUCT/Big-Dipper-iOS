//
//  MockCommunityRepositories.swift
//  AppProduct
//

import Foundation

// MARK: - MockCommunityRepository

/// 게스트 세션 및 프리뷰용 Community Repository Mock 구현체
final class MockCommunityRepository: CommunityRepositoryProtocol {

    func getSchools() async throws -> [String] {
        ["UMC 대학교", "성균관대학교", "한양대학교", "서울대학교", "연세대학교"]
    }

    func getTrophies(query: TrophyListQuery) async throws -> [CommunityFameItemModel] {
        try await Task.sleep(for: .milliseconds(200))
        return CommunityMockData.trophies
    }

    func getPosts(query: PostListQuery) async throws -> (
        items: [CommunityItemModel],
        hasNext: Bool
    ) {
        try await Task.sleep(for: .milliseconds(200))
        let all = CommunityMockData.posts
        guard let category = query.category else {
            return (items: all, hasNext: false)
        }
        let filtered = all.filter { $0.category.rawValue == category }
        return (items: filtered, hasNext: false)
    }

    func getSearch(query: PostSearchQuery) async throws -> (
        items: [CommunityItemModel],
        hasNext: Bool
    ) {
        try await Task.sleep(for: .milliseconds(200))
        let keyword = query.keyword.lowercased()
        let filtered = CommunityMockData.posts.filter {
            $0.title.lowercased().contains(keyword) ||
            $0.content.lowercased().contains(keyword)
        }
        return (items: filtered, hasNext: false)
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
        CommunityMockData.comments
    }

    func getPostDetail(postId: Int) async throws -> CommunityItemModel {
        if let match = CommunityMockData.posts.first(where: { $0.postId == postId }) {
            return match
        }
        return CommunityMockData.posts.first ?? CommunityMockData.fallbackPost(postId: postId)
    }

    func postScrap(postId: Int) async throws {}

    func postLike(postId: Int) async throws {}

    func postComment(postId: Int, request: PostCommentRequest) async throws {}

    func postPostReport(postId: Int) async throws {}

    func postCommentReport(commentId: Int) async throws {}
}
