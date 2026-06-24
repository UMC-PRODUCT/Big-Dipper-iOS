//
//  NoticeModel.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation
import UMCFoundation

// MARK: - NoticeScope
/// 공지 출처 (어디서 온 공지인지)
public enum NoticeScope: Equatable, Hashable {
    // 중앙
    case central
    // 지부
    case branch
    // 교내
    case campus
}

// MARK: - NoticeCategory
/// 공지 카테고리 (일반/파트별)
public enum NoticeCategory: Equatable, Hashable {
    // 일반 공지
    case general
    // 파트별 공지
    case part(UMCPartType)
}

