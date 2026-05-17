//
//  CheckEmailAvailabilityResponseDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

/// 이메일 중복 검사 API 응답 DTO
///
/// `GET /api/v1/auth/email/availability`
struct CheckEmailAvailabilityResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 검사 대상 이메일 (서버가 정규화하여 반환)
    let email: String
    /// 사용 가능 여부 (true: 사용 가능, false: 이미 사용 중)
    let available: Bool
}
