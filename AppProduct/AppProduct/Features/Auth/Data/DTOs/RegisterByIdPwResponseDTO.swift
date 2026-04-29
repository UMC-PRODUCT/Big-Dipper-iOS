//
//  RegisterByIdPwResponseDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// ID/PW 회원가입 API 응답 DTO
struct RegisterByIdPwResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 생성된 회원 ID (서버 응답 String)
    let memberId: String
    /// JWT 액세스 토큰
    let accessToken: String
    /// JWT 리프레시 토큰
    let refreshToken: String

    // MARK: - Mapping

    /// Domain 모델로 변환
    func toDomain() -> RegisterByIdPwResult {
        RegisterByIdPwResult(
            memberId: memberId,
            tokenPair: TokenPair(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        )
    }
}
