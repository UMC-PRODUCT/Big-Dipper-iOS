//
//  CheckEmailAvailabilityQuery.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

/// 이메일 중복 검사 Query DTO
///
/// `GET /api/v1/auth/email/availability?email=...`
struct CheckEmailAvailabilityQuery: Encodable {

    // MARK: - Property

    /// 검사 대상 이메일 주소
    let email: String

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        ["email": email]
    }
}
