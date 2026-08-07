//
//  NavigationTab+Presentation.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import SwiftUI

import CoreRouting

/// 루트 탭 셸이 각 탭을 어떻게 보여줄지에 대한 App 쪽 표현.
///
/// 탭의 라우팅 정체성은 `CoreRouting.NavigationTab` 이 갖고, 제목·아이콘·역할처럼 앱 셸에서만
/// 쓰는 표현은 여기서 붙인다. 그래야 Feature 모듈이 경로를 다루려고 탭 표현까지 의존하지 않는다.
extension NavigationTab {

    var title: String {
        switch self {
        case .home: "홈"
        case .notice: "공지"
        case .activity: "활동"
        case .community: "커뮤니티"
        case .mypage: "마이페이지"
        }
    }

    var systemImageName: String {
        switch self {
        case .home: "house"
        case .notice: "list.bullet.clipboard"
        case .activity: "folder.badge.person.crop"
        case .community: "bubble.left.and.bubble.right"
        case .mypage: "person.fill"
        }
    }

    var role: TabRole? {
        switch self {
        case .mypage: .search
        default: nil
        }
    }
}
