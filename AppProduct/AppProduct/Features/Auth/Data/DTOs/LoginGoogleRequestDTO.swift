//
//  LoginGoogleRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import Foundation

/// Google 소셜 로그인 요청 DTO
///
/// `POST /api/v1/auth/login/google`
///
/// - Important: `accessToken` 필드명이지만, 서버는 이 값으로 **Google idToken**의
///   진위를 검증합니다. 카카오의 `accessToken`(카카오 OAuth 액세스 토큰)과 의미가 다릅니다.
struct LoginGoogleRequestDTO: Encodable {
    /// 서버 검증용 Google **idToken** (서버 스펙상 필드명은 `accessToken`)
    let accessToken: String
    /// 클라이언트 플랫폼 (`IOS`)
    let clientType: String
}
