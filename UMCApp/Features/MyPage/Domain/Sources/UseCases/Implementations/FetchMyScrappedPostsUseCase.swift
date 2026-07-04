//
//  FetchMyScrappedPostsUseCase.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation

public final class FetchMyScrappedPostsUseCase: FetchMyScrappedPostsUseCaseProtocol {
    
    // MARK: - Property
    
    private let repository: MyPageRepositoryProtocol
    
    // MARK: - Function
    
    public init(repository: MyPageRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await repository.fetchScrappedPosts(query: query)
    }
}
