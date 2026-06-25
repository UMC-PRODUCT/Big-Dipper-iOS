//
//  FetchMyCommentedPostsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

public protocol FetchMyCommentedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage
}
