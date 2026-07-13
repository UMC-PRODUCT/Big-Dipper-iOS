//
//  TabCase.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import SwiftUI

/// 루트 탭 셸이 표시하는 5개 탭.
///
/// 이번 이슈(#910)의 최소 수직 슬라이스에서는 `.home`만 실제 화면에 연결되고
/// 나머지 탭은 placeholder(`{Feature}FeatureView`)를 표시한다.
enum TabCase: CaseIterable, Identifiable, Hashable {
    case home
    case notice
    case activity
    case community
    case mypage

    var id: Self { self }

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
