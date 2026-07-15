//
//  MemberStatus.swift
//  UMCFoundation
//
//  Created by euijjang97 on 6/25/26.
//

import Foundation

/// 멤버 활동 상태
public enum MemberStatus: String, Codable, Equatable, Hashable, Sendable {
    /// 활동 중
    case active = "ACTIVE"
    /// 비활성
    case inactive = "INACTIVE"
    /// 탈퇴
    case withdrawn = "WITHDRAWN"
}
