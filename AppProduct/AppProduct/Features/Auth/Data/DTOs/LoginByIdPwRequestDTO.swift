//
//  LoginByIdPwRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// ID/PW 로그인 API 요청 DTO
struct LoginByIdPwRequestDTO: Encodable {

    // MARK: - Property

    /// 로그인 ID (사용자 입력)
    let loginId: String
    /// 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    let password: String
}
