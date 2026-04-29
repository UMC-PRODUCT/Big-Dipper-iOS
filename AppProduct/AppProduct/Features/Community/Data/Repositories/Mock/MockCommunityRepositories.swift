//
//  MockCommunityRepositories.swift
//  AppProduct
//

import Foundation

// MARK: - MockCommunityRepository

/// 프리뷰 및 테스트용 Community Repository Mock 구현체
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

/// 프리뷰 및 테스트용 Community Post Repository Mock 구현체
final class MockCommunityPostRepository: CommunityPostRepositoryProtocol {

    func postPosts(request: PostRequestDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postLightning(request: CreateLightningPostRequestDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func patchPosts(postId: Int, request: PostRequestDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func patchLightning(postId: Int, request: CreateLightningPostRequestDTO) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}

// MARK: - MockCommunityDetailRepository

/// 프리뷰 및 테스트용 Community Detail Repository Mock 구현체
final class MockCommunityDetailRepository: CommunityDetailRepositoryProtocol {

    func deletePost(postId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func deleteComment(postId: Int, commentId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func getComments(postId: Int) async throws -> [CommunityCommentModel] {
        []
    }

    func getPostDetail(postId: Int) async throws -> CommunityItemModel {
        throw DomainError.postNotFound
    }

    func postScrap(postId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postLike(postId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postComment(postId: Int, request: PostCommentRequest) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postPostReport(postId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func postCommentReport(commentId: Int) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}
