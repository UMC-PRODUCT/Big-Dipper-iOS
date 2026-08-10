//
//  LawsType.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import Foundation
import SwiftUI

/// MyPage에서 표시되는 법률 문서 타입
///
/// 개인정보처리 방침, 이용약관을 구분하고 약관 조회 API의 `termsType` 값과 표시용 아이콘·색상을 제공합니다.
public enum LawsType: String, CaseIterable {
    /// 개인정보처리 방침
    case policy = "개인정보처리 방침"
    /// 이용약관
    case terms = "이용약관"

    /// 약관 조회 API에서 사용하는 termsType 값
    public var apiType: String {
        switch self {
        case .policy:
            return "PRIVACY"
        case .terms:
            return "SERVICE"
        }
    }

    /// 각 법률 문서 타입에 맞는 SF Symbol 아이콘 이름
    public var icon: String {
        switch self {
        case .policy:
            return "hand.raised.fill"
        case .terms:
            return "doc.text.fill"
        }
    }

    /// 각 법률 문서 타입에 맞는 테마 색상
    public var color: Color {
        switch self {
        case .policy:
            return .purple
        case .terms:
            return .indigo
        }
    }
}
