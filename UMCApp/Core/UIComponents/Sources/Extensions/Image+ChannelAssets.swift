//
//  Image+ChannelAssets.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 8/10/26.
//

import SwiftUI

// MARK: - Image + Channel Assets

/// `CoreUIComponents` 번들의 UMC 공식 채널 아이콘 접근자
///
/// 번들 해석 이유는 ``Image/umcMapPin`` 과 동일합니다 — 문자열 + `Bundle.module` 은
/// 선언한 모듈의 번들로만 해석되므로, Feature 모듈에서 직접 쓰면 자기 번들을 찾다 실패합니다.
public extension Image {

    /// UMC 공식 Instagram 계정 아이콘
    static var umcInstagram: Image {
        Image("instagram", bundle: .module)
    }

    /// UMC 공식 웹사이트 아이콘 (정사각 로고)
    static var umcChannelLogo: Image {
        Image("umcLogo", bundle: .module)
    }
}
