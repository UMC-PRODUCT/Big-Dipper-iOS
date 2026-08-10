//
//  SocialLinkType+UI.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import MyPageDomain
import SwiftUI

/// `SocialLinkType`의 표시용 프로퍼티.
///
/// 도메인 열거형은 서버 문자열만 알고, 아이콘·라벨은 Presentation에서 붙인다.
public extension SocialLinkType {

    /// 링크 종류를 나타내는 SF Symbol 이름
    var icon: String {
        switch self {
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        case .linkedin:
            return "person.crop.rectangle"
        case .blog:
            return "text.book.closed"
        }
    }

    /// 행에 노출할 서비스 이름
    var title: String {
        switch self {
        case .github:
            return "GitHub"
        case .linkedin:
            return "LinkedIn"
        case .blog:
            return "Blog"
        }
    }

    /// 아이콘 배경에 사용하는 테마 색상
    var color: Color {
        switch self {
        case .github:
            return .black
        case .linkedin:
            return .blue
        case .blog:
            return .brown
        }
    }
}
