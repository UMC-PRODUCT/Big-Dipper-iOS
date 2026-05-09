//
//  FetchMyScrappedPostsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

public protocol FetchMyScrappedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage
}
