//
//  MyPagePostListQuery.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 마이페이지 게시글 목록 조회 쿼리
///
/// 페이지 / 사이즈 / 정렬 정보를 캡슐화합니다. 직렬화는 Data 레이어 책임.
public struct MyPagePostListQuery: Equatable, Hashable {
    public let page: String
    public let size: String
    public let sort: [String]

    public init(
        page: String = "0",
        size: String = "20",
        sort: [String] = ["createdAt,DESC"]
    ) {
        self.page = page
        self.size = size
        self.sort = sort
    }
}
