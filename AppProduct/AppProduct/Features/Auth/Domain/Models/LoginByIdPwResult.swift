//
//  LoginByIdPwResult.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// ID/PW 로그인 결과
///
/// 소셜 로그인과 달리 신규 회원 분기가 없습니다 (회원가입은 별도 플로우).
struct LoginByIdPwResult: Equatable, Sendable {

    // MARK: - Property

    /// 회원 ID (서버 응답 String)
    let memberId: String
    /// 인증 토큰 쌍
    let tokenPair: TokenPair
}
