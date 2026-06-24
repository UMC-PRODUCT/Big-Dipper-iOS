//
//  NoticeType+UI.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/8/26.
//

import SwiftUI
import NoticeDomain
import CoreDesignSystem

extension NoticeType {
    /// 필독 유형의 공지 칩
    public var textColor: Color {
        switch self {
        case .essential:
            return .indigo500
        default:
            return .white
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .essential:
            return .indigo100
        default:
            return .indigo500
        }
    }
}
