//
//  RegisterResponseDTO.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

/// 회원가입 API 응답 DTO
///
/// 서버가 회원가입 응답에 토큰을 함께 내려주면(`accessToken`/`refreshToken`) 별도 재로그인
/// 없이 그대로 세션을 복구할 수 있습니다. 토큰 필드는 서버 스펙에 따라 없을 수 있으므로
/// 옵셔널로 디코딩하고, 없으면 기존 소셜 재로그인 경로로 폴백합니다.
struct RegisterResponseDTO: Codable {

    // MARK: - Property

    /// 생성된 회원 ID (서버가 String 반환)
    let memberId: String

    /// JWT 액세스 토큰 (서버가 가입 응답에 포함할 경우)
    let accessToken: String?

    /// JWT 리프레시 토큰 (서버가 가입 응답에 포함할 경우)
    let refreshToken: String?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case memberId
        case accessToken
        case refreshToken
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decode(String.self, forKey: .memberId)
        accessToken = try container.decodeIfPresent(
            String.self,
            forKey: .accessToken
        )
        refreshToken = try container.decodeIfPresent(
            String.self,
            forKey: .refreshToken
        )
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
    }

    // MARK: - Mapping

    /// Domain 모델로 변환합니다.
    ///
    /// `accessToken`/`refreshToken`이 모두 비어있지 않을 때만 `tokenPair`를 구성합니다.
    func toDomain() -> RegisterResult {
        let trimmedAccess = accessToken?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedRefresh = refreshToken?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let tokenPair: TokenPair?
        if let trimmedAccess, !trimmedAccess.isEmpty,
           let trimmedRefresh, !trimmedRefresh.isEmpty {
            tokenPair = TokenPair(
                accessToken: trimmedAccess,
                refreshToken: trimmedRefresh
            )
        } else {
            tokenPair = nil
        }

        return RegisterResult(memberId: memberId, tokenPair: tokenPair)
    }
}
