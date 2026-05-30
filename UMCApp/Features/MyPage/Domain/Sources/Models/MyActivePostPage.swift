//
//  MyActivePostPage.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
import CoreDomain

/// 마이페이지에서 조회하는 게시글 목록 페이지 모델
public struct MyActivePostPage: Equatable, Hashable {
    public let items: [CommunityItemModel]
    public let page: String
    public let hasNext: Bool

    public init(items: [CommunityItemModel], page: String, hasNext: Bool) {
        self.items = items
        self.page = page
        self.hasNext = hasNext
    }
}
