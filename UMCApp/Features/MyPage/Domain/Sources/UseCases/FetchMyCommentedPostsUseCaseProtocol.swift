//
//  FetchMyCommentedPostsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
/// 댓글 단 글 조회  UseCase Protocol
///
/// 내가 댓글단 글들을 조회합니다.
public protocol FetchMyCommentedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage
}
