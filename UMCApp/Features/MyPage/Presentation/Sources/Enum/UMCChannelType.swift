//
//  UMCChannelType.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import SwiftUI

/// 마이페이지에 노출하는 UMC 공식 채널.
///
/// 레거시 `FollowType` 의 이식본이다. 팔로우 기능이 아니라 공식 채널 링크 모음이라
/// 이름을 역할에 맞게 바꿨다.
public enum UMCChannelType: String, CaseIterable {
    /// UMC 공식 Instagram 계정
    case instagram
    /// UMC 공식 웹사이트
    case webSite

    /// 웹 브라우저로 열 URL
    public var url: URL? {
        switch self {
        case .instagram:
            return URL(string: "https://www.instagram.com/uni_makeus_challenge/")
        case .webSite:
            return URL(string: "https://umc.it.kr")
        }
    }

    /// 앱이 설치돼 있을 때 우선 시도할 딥링크. 없으면 `url` 로 바로 연다.
    public var appURL: URL? {
        switch self {
        case .instagram:
            return URL(string: "instagram://user?username=uni_makeus_challenge")
        case .webSite:
            return nil
        }
    }

    /// 채널 아이콘 (`CoreUIComponents` 번들 자산)
    public var icon: Image {
        switch self {
        case .instagram:
            return .umcInstagram
        case .webSite:
            return .umcChannelLogo
        }
    }

    /// VoiceOver 로 읽어줄 채널 이름
    public var accessibilityLabel: String {
        switch self {
        case .instagram:
            return "UMC 인스타그램"
        case .webSite:
            return "UMC 공식 웹사이트"
        }
    }
}
