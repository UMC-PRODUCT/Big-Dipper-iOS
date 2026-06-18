//
//  RegisterResult.swift
//  AppProduct
//
//  Created by euijjang97 on 6/18/26.
//

import Foundation

/// 소셜 회원가입 결과
///
/// 서버가 가입 응답에 토큰을 함께 내려주면 `tokenPair`가 채워져 별도 재로그인 없이
/// 즉시 세션을 복구할 수 있습니다. 토큰이 없으면 `nil`이며, 호출부는 기존 소셜
/// 재로그인 경로로 폴백합니다.
struct RegisterResult: Equatable, Sendable {

    // MARK: - Property

    /// 생성된 회원 ID (서버 응답 String)
    let memberId: String

    /// 가입과 동시에 발급된 토큰 쌍 (서버가 제공하지 않으면 `nil`)
    let tokenPair: TokenPair?
}
