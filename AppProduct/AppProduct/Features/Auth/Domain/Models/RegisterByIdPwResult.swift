//
//  RegisterByIdPwResult.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// ID/PW 회원가입 결과
///
/// 가입과 동시에 토큰 쌍이 발급되어 별도 로그인 호출 없이 메인 진입이 가능합니다.
struct RegisterByIdPwResult: Equatable, Sendable {

    // MARK: - Property

    /// 생성된 회원 ID (서버 응답 String)
    let memberId: String
    /// 인증 토큰 쌍
    let tokenPair: TokenPair
}
