//
//  EmailLoginRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

/// 이메일 로그인 API 요청 DTO
///
/// `POST /api/v1/auth/login/email`
struct EmailLoginRequestDTO: Encodable {

    // MARK: - Property

    /// 이메일 주소
    let email: String
    /// 평문 비밀번호 (TLS 구간 서버 해싱 위임)
    let password: String
}
