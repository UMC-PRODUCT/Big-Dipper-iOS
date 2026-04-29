//
//  CheckLoginIdAvailabilityResponseDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// 로그인 ID 중복 검사 API 응답 DTO
struct CheckLoginIdAvailabilityResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 검사 대상 로그인 ID (서버가 정규화하여 반환)
    let loginId: String
    /// 사용 가능 여부 (true: 사용 가능, false: 이미 사용 중)
    let available: Bool
}
