//
//  FetchMyPostsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
/// 내 글 조회 UseCase Protocol
///
/// MyPage에서 내가 작성한 글들의 정보를 조회합니다.
public protocol FetchMyPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage
}
