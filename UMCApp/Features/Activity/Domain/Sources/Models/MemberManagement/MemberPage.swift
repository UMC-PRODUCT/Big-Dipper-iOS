//
//  MemberPage.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation

/// 멤버 관리 목록의 한 페이지 (offset 기반 페이지네이션)
///
/// 멤버 조회 서버 API 가 offset(page) 기반이므로 페이지 인덱스를 그대로 보존합니다.
public struct MemberPage: Equatable {

    /// 현재 페이지의 멤버 목록
    public let members: [MemberManagementItem]

    /// 다음 페이지 존재 여부
    public let hasNext: Bool

    /// 현재 페이지 인덱스 (0-based)
    public let currentPage: Int

    public init(members: [MemberManagementItem], hasNext: Bool, currentPage: Int) {
        self.members = members
        self.hasNext = hasNext
        self.currentPage = currentPage
    }
}
