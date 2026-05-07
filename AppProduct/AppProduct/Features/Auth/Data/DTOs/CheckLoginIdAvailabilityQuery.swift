//
//  CheckLoginIdAvailabilityQuery.swift
//  AppProduct
//
//  Created by euijjang97 on 5/7/26.
//

import Foundation

/// 로그인 ID 중복 검사 Query DTO
///
/// `GET /api/v1/auth/login-id/availability`
struct CheckLoginIdAvailabilityQuery: Encodable {
    /// 검사 대상 로그인 ID
    let loginId: String

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        ["loginId": loginId]
    }
}
