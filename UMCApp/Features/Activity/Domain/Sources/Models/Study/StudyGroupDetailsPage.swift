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

    /// 다음 페이지 커서 (서버 응답)
    public let nextCursor: String?

    public init(content: [StudyGroupInfo], hasNext: Bool, nextCursor: String?) {
        self.content = content
        self.hasNext = hasNext
        self.nextCursor = nextCursor
    }
}
