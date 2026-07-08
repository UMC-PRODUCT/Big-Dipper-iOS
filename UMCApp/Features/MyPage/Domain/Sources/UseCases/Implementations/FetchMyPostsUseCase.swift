//
//  FetchMyPostsUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

/// 내 글들 조회 구현체
public final class FetchMyPostsUseCase: FetchMyPostsUseCaseProtocol {
    
    // MARK: - Property
   
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await repository.fetchMyPosts(query: query)
    }
}
