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
/// - Important: `accessToken` 필드에는 GoogleSignIn에서 발급받은 **구글 OAuth accessToken**
///   (`ya29...`)을 담습니다. 서버는 이 토큰으로 구글에 사용자 진위를 조회합니다.
///   (카카오와 동일하게 provider의 OAuth accessToken을 전달합니다. Swagger 설명의 "idToken"은 오기입니다.)
struct LoginGoogleRequestDTO: Encodable {
    /// 서버 검증용 구글 OAuth accessToken
    let accessToken: String
    /// 클라이언트 플랫폼 (`IOS`)
    let clientType: String
}
