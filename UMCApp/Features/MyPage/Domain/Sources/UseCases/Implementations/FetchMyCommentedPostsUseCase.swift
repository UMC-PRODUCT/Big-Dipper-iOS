//
//  FetchMyCommentedPostsUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 댓글 단 글들 조회 UseCase 구현체
public final class FetchMyCommentedPostsUseCase: FetchMyCommentedPostsUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await repository.fetchCommentedPosts(query: query)
    }
}
