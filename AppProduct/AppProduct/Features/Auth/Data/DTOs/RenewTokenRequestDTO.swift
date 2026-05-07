//
//  RenewTokenRequestDTO.swift
//  AppProduct
//
//  Created by JEONG on 5/7/26.
//

import Foundation

/// 액세스 토큰 재발급 요청 DTO
///
/// `POST /api/v1/auth/token/renew`
struct RenewTokenRequestDTO: Encodable {
    /// 리프레시 토큰
    let refreshToken: String
}
