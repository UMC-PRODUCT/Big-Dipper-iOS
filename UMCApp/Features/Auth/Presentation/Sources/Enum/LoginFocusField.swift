//
//  LoginFocusField.swift
//  AuthPresentation
//
//  Created by euijjang97 on 7/31/26.
//

import Foundation

/// 이메일(ID/PW) 로그인 화면(`EmailLoginView`)의 키보드 포커스 대상 필드.
///
/// 회원가입 화면과 필드 구성이 다르므로 `SignUpFocusField`를 재사용하지 않고 분리한다.
enum LoginFocusField: Hashable, CaseIterable {
    case email
    case password
}
