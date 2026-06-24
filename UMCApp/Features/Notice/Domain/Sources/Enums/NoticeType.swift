//
//  NoticeType.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation

// MARK: - NoticeType
/// NoticeChip에 쓰이는 enum
public enum NoticeType: String, Equatable {
    case essential = "필독"
    case core = "중앙"
    case branch = "지부"
    case campus = "교내"
    case part = "파트"
}
