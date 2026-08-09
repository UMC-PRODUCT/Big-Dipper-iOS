//
//  Image+ProfileAssets.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 8/9/26.
//

import SwiftUI

// MARK: - Image + Profile Assets

/// `CoreUIComponents` 번들의 프로필 관련 이미지 자산 접근자
///
/// `Image+MapAssets` 와 같은 이유로 존재합니다. 본 모듈은
/// `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` 라 생성 심볼(`Image(.defaultProfile)`)이
/// 없고, `Bundle.module` 은 **선언한 모듈의 번들로만** 해석되므로 Feature 모듈이
/// `Image("defaultProfile", bundle: .module)` 을 직접 쓰면 자기 번들을 찾다 실패합니다.
public extension Image {

    /// 프로필 이미지가 없거나 로드에 실패했을 때 쓰는 기본 프로필
    static var umcDefaultProfile: Image {
        Image("defaultProfile", bundle: .module)
    }
}
