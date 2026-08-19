//
//  SocialLinkType+UI.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import MyPageDomain
import SwiftUI

/// `SocialLinkType`의 표시용 프로퍼티.
///
/// 도메인 열거형은 서버 문자열만 알고, 아이콘·라벨은 Presentation에서 붙인다.
public extension SocialLinkType {

    /// 링크 종류의 브랜드 아이콘 (컬러, 32×32 라운드 8 틀에 얹는다).
    ///
    /// 시안(`Figma 12736:32709` 외부 링크 · `12804:30609` 외부 프로필 링크)이 SF Symbol
    /// 이 아니라 서비스 브랜드 이미지를 쓴다 — 설정·프로필 수정 두 화면이 같은 에셋을
    /// 공유한다.
    var brandIcon: Image {
        switch self {
        case .github:
            return .githubColor
        case .linkedin:
            return .linkedInColor
        case .blog:
            return .blogColor
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

    /// ``title`` 뒤에 붙는 목적격 조사.
    ///
    /// 시안(`12736:32900`·`33150`·`33400`)의 알럿 제목이 「Github**를**」/「LinkedIn**을**」
    /// 처럼 조사를 가려 쓴다. 표기는 영문이지만 조사는 한글 발음의 종성을 따르므로
    /// (`LinkedIn` → 「인」의 ㄴ 받침) 문자열로는 판별할 수 없어 종류별로 못박는다.
    var objectParticle: String {
        switch self {
        case .github, .blog:
            return "를"
        case .linkedin:
            return "을"
        }
    }

    /// 링크 입력 필드에 노출할 예시 URL
    var placeholder: String {
        switch self {
        case .github:
            return "https://github.com/"
        case .linkedin:
            return "https://linkedin.com/in/yourprofile"
        case .blog:
            return "https://yourblog.com"
        }
    }
}
