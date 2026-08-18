//
//  Image+BusinessCardAssets.swift
//  CoreUIComponents
//
//  Created by One on 8/18/26.
//

import SwiftUI

// MARK: - Image + BusinessCard Assets

/// `CoreUIComponents` 번들의 명함 관련 이미지 자산 접근자
///
/// `Image+ProfileAssets` 와 같은 이유로 존재합니다. 본 모듈은
/// `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` 라 생성 심볼이 없고,
/// `Bundle.module` 은 **선언한 모듈의 번들로만** 해석되므로 Feature 모듈이
/// `Image("...", bundle: .module)` 을 직접 쓰면 자기 번들을 찾다 실패합니다.
///
/// - Note: 자산이 여기 사는 이유는 `featureProject` 에 Presentation 리소스 슬롯이
///   없어서입니다(`dataResources` 만 있음). 지도·채널 이미지도 같은 이유로 여기 있습니다.
public extension Image {

    /// 명함 교환 완료 화면의 200×200 일러스트 (`Figma 12657:37832`).
    ///
    /// 벡터 보존 SVG 라 지정한 프레임 크기로 선명하게 그려집니다.
    static var umcExchangeCompleted: Image {
        Image("exchangeCompleted", bundle: .module)
    }

    /// 명함 카드 헤더의 UMC 워드마크 47×15.16 (`Figma I12639:33234;12639:33199`).
    ///
    /// 흰색 고정 브랜드 로고라 template 렌더링 없이 원본을 그대로 씁니다.
    static var umcWordmark: Image {
        Image("umcWordmark", bundle: .module)
    }

    /// 명함 뒷면의 GitHub 브랜드 아이콘 18×18, 흰색 모노 (`Figma 12766:98577`).
    static var githubMono: Image {
        Image("githubMono", bundle: .module)
    }

    /// 명함 뒷면의 LinkedIn 브랜드 아이콘 18×18, 흰색 모노 (`Figma 12766:98582`).
    static var linkedInMono: Image {
        Image("linkedInMono", bundle: .module)
    }
}
