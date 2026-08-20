//
//  Image+MyPageAssets.swift
//  CoreUIComponents
//
//  Created by One on 8/19/26.
//

import SwiftUI

// MARK: - Image + MyPage Assets

/// `CoreUIComponents` 번들의 마이페이지 관련 이미지 자산 접근자
///
/// `Image+BusinessCardAssets` 와 같은 이유로 존재합니다. 본 모듈은
/// `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` 라 생성 심볼이 없고,
/// `Bundle.module` 은 **선언한 모듈의 번들로만** 해석되므로 Feature 모듈이
/// `Image("...", bundle: .module)` 을 직접 쓰면 자기 번들을 찾다 실패합니다.
public extension Image {

    /// 외부 링크 행의 GitHub 브랜드 아이콘, 컬러 원형 (`Figma 12736:32711`).
    ///
    /// 명함 뒷면의 흰색 모노(``githubMono``)와 달리 리스트 행에서 쓰는 원본 컬러판입니다.
    static var githubColor: Image {
        Image("githubColor", bundle: .module)
    }

    /// 외부 링크 행의 LinkedIn 브랜드 아이콘, 컬러 원형 (`Figma 12736:32718`).
    static var linkedInColor: Image {
        Image("linkedInColor", bundle: .module)
    }

    /// 외부 링크 행의 Blog 체인링크 아이콘, 컬러 (`Figma 12736:32725`).
    static var blogColor: Image {
        Image("blogColor", bundle: .module)
    }

    /// 소셜계정 연동 행의 카카오 아이콘 — 노란 타일에 말풍선 (`Figma 12736:32834`).
    ///
    /// 로그인 버튼의 글리프(``SocialType/image``)와 달리 배경까지 구운 타일판이라
    /// 리스트 행에 그대로 얹는다.
    static var kakaoColor: Image {
        Image("kakaoColor", bundle: .module)
    }

    /// 소셜계정 연동 행의 Apple 아이콘 — 검은 타일에 흰 사과 (`Figma 12736:32841`).
    static var appleColor: Image {
        Image("appleColor", bundle: .module)
    }
}
