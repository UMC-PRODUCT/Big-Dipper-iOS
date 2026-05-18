//
//  StudyGroupDetailsPage.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 스터디 그룹 상세 페이지 (커서 기반 페이지네이션)
public struct StudyGroupDetailsPage: Equatable {

    public let content: [StudyGroupInfo]
    public let hasNext: Bool
    public let nextCursor: Int?

    public init(content: [StudyGroupInfo], hasNext: Bool, nextCursor: Int?) {
        self.content = content
        self.hasNext = hasNext
        self.nextCursor = nextCursor
    }
}
