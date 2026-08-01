//
//  Image+MapAssets.swift
//  CoreUIComponents
//
//  Created by jaewon Lee on 7/30/26.
//

import SwiftUI

// MARK: - Image + Map Assets

/// `CoreUIComponents` 번들의 지도 관련 이미지 자산 접근자
///
/// 자산은 `Resources/Images.xcassets/Map` 에 있고, 본 모듈은
/// `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` 라 생성 심볼(`Image(.Map.x)`)을 쓸 수 없습니다.
/// 문자열 + `Bundle.module` 조합은 **선언한 모듈의 번들로만** 해석되므로, Feature 모듈이
/// `Image("MapPin", bundle: .module)` 을 직접 쓰면 자기 번들을 찾다 실패합니다.
/// 따라서 자산 이름과 번들 해석을 이 확장 한 곳에 가두고, 소비자는 접근자만 사용합니다.
public extension Image {

    /// 지도 위 장소를 가리키는 핀 마커
    static var umcMapPin: Image {
        Image("MapPin", bundle: .module)
    }

    /// 위치 인증(지오펜스 내부) 상태 아이콘
    static var umcVerifyLocation: Image {
        Image("VerifyLocation", bundle: .module)
    }
}
