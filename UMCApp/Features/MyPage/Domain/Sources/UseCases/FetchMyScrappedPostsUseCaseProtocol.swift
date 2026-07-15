//
//  FetchMyScrappedPostsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
/// 스크랩한 글들 조회  UseCase Protocol
///
/// MyPage에서 내가 스크랩한 글들을 조회합니다.
public protocol FetchMyScrappedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage
}
