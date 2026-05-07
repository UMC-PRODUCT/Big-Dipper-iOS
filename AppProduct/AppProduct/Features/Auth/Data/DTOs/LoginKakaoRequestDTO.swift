//
//  LoginKakaoRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 카카오 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/kakao`
struct LoginKakaoRequestDTO: Encodable {
    /// 카카오 SDK 액세스 토큰
    let accessToken: String
    /// 카카오 계정 이메일
    let email: String
}
