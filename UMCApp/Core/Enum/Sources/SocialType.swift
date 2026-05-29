//
//  SocialType.swift
//  CoreEnum
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// 앱에서 지원하는 소셜 로그인 타입을 정의하는 열거형입니다.
///
/// UI 프로퍼티(image/color)는 사용처 Presentation 모듈의 extension으로 제공합니다.
public enum SocialType: String, CaseIterable, Hashable {
    /// 카카오 로그인
    case kakao = "Kakao"
    /// 애플 로그인
    case apple = "Apple"
    /// 구글 로그인
    case google = "Google"
    
    /// 앱에서 직접 로그인/연동 추가를 지원하는 소셜 목록입니다.
    public static var appConnectableCases: [SocialType] {
        [.kakao, .apple]
    }

    /// 서버 provider 문자열("KAKAO", "APPLE" 등)로 변환합니다.
    public init?(provider: String) {
        switch provider.uppercased() {
        case "KAKAO":
            self = .kakao
        case "APPLE":
            self = .apple
        case "GOOGLE":
            self = .google
        default:
            return nil
        }
    }
}
