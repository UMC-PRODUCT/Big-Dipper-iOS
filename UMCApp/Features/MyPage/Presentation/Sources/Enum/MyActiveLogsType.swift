//
//  MyActiveLogsType.swift
//  MyPage
//
//  Created by 김동민 on 7/13/26.
//

import Foundation
import SwiftUI

/// 사용자의 활동 내역 타입을 정의하는 열거형
///
/// 커뮤니티 내에서 사용자가 수행한 활동(글 작성, 댓글, 스크랩)을 분류하고 각각의 아이콘 및 배경 색상을 제공합니다.
public enum MyActiveLogsType: String, CaseIterable {
    /// 사용자가 직접 작성한 게시글
    case myWritePost = "내가 쓴 글"
    /// 사용자가 댓글을 남긴 게시글
    case myWriteComment = "댓글 단 글"
    /// 사용자가 스크랩한 게시글
    case myScrapPost = "스크랩"
    
    /// 각 활동 타입에 맞는 SF Symbol 아이콘 이름
    public var icon: String {
        switch self {
        case .myWritePost:
            return "square.and.pencil"
        case .myWriteComment:
            return "bubble.right"
        case .myScrapPost:
            return "bookmark"
        }
    }
    
    /// 각 활동 타입에 맞는 배경 색상 (UI에서 구분을 위해 사용)
    public var backgroundColor: Color {
        switch self {
        case .myWritePost:
            return .blue
        case .myWriteComment:
            return .green
        case .myScrapPost:
            return .orange
        }
    }
}
