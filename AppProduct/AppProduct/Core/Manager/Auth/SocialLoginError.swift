//
//  SocialLoginError.swift
//  AppProduct
//
//  Created by euijjang97 on 6/10/26.
//

import Foundation

/// 소셜 로그인(Google/Kakao/Apple) 과정에서 발생하는 공통 에러입니다.
///
/// 각 SDK의 취소 에러를 이 타입으로 정규화해, 상위 레이어(ViewModel)가
/// 특정 SDK에 의존하지 않고 "사용자 취소"를 구분할 수 있게 합니다.
enum SocialLoginError: Error, Equatable {

    /// 사용자가 소셜 로그인 화면에서 취소(X)한 경우입니다.
    ///
    /// 정상적인 사용자 행동이므로 에러 알럿을 띄우지 않고 조용히 무시해야 합니다.
    case cancelled
}
