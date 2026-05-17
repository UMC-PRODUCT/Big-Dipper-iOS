//
//  SignUpByIdPwField.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// 이메일 회원가입 화면의 키보드 포커스 대상 필드
///
/// 부모 `SignUpByIdPwView`가 `@FocusState`로 보유하고,
/// 분리된 섹션 컴포넌트(`SignUpPasswordSection`, `SignUpNameNicknameSection`)가
/// `FocusState.Binding`으로 공유하여 한 곳에서 포커스 흐름을 일원 관리합니다.
enum SignUpByIdPwField: Hashable, CaseIterable {
    case password
    case passwordConfirm
    case name
    case nickname
}
