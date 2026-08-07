//
//  LoginMethod.swift
//  CoreUIComponents
//
//  Created by euijjang97 on 7/31/26.
//

import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 로그인 화면이 제공하는 로그인 수단.
///
/// `SocialType`(UMCFoundation)은 순수 OAuth provider 도메인 개념이라 `.email`을 넣지 않는다.
/// 레거시가 `SocialType`에 `.email`을 끼워 넣었던 이유는 버튼 라벨 스타일 재사용뿐이었으므로,
/// 그 관심사를 이 열거형으로 분리한다. (#943)
///
/// - Note: 이 타입을 소비하는 `SocialLoginLabel`·`LoginActionStack`이 CoreUIComponents에 있고
///   CoreUIComponents는 AuthPresentation에 의존할 수 없어(의존 방향이 반대), 이슈 본문이 지정한
///   `Features/Auth/Presentation/` 대신 같은 모듈에 배치한다.
/// - Note: `Sendable`을 채택하지 않는다. `SocialType`이 public이라 암시적 `Sendable` 추론
///   대상이 아니고(추론은 non-public 한정), 연관값으로 품은 채 `Sendable`을 선언하면
///   Swift 6 언어 모드에서 컴파일 에러다. 이 타입은 main actor View 본문에서만 읽히므로
///   실사용상 필요도 없다.
public enum LoginMethod: Hashable, CaseIterable {
    /// 소셜 로그인 (카카오 / Apple / Google)
    case social(SocialType)
    /// UMC 계정(ID/PW) 로그인
    case email

    public static var allCases: [LoginMethod] {
        SocialType.allCases.map(LoginMethod.social) + [.email]
    }
}

// MARK: - UI

/// 로그인 버튼 라벨의 표현 속성. `.social`은 `SocialType+UI`의 값에 그대로 위임하고,
/// `.email`만 UMC 계정 전용 값을 갖는다.
public extension LoginMethod {

    /// 로그인 버튼에 노출할 문구.
    var loginButtonTitle: String {
        switch self {
        case .social(let type):
            return type.loginButtonTitle
        case .email:
            return "UMC 계정 로그인"
        }
    }

    /// 마이페이지 연동 섹션 등에서 사용하는 표시용 이름.
    var displayName: String {
        switch self {
        case .social(let type):
            return type.displayName
        case .email:
            return "이메일"
        }
    }

    /// 로그인 수단에 해당하는 로고 이미지.
    var image: Image {
        switch self {
        case .social(let type):
            return type.image
        case .email:
            return Image("email", bundle: .module)
        }
    }

    /// 버튼 배경 색상.
    var color: Color {
        switch self {
        case .social(let type):
            return type.color
        case .email:
            return .green100
        }
    }

    /// 버튼 위 텍스트/아이콘 색상.
    var fontColor: Color {
        switch self {
        case .social(let type):
            return type.fontColor
        case .email:
            return .green700
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .social(let type):
            return type.iconSize
        case .email:
            return 24
        }
    }
}
