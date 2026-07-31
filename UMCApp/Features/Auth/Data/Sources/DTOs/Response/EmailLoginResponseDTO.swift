//
//  EmailLoginResponseDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/31/26.
//

import UMCFoundation

/// 이메일(ID/PW) 로그인 API 응답 DTO
///
/// 이메일 로그인은 서버가 인증 성공과 동시에 항상 토큰을 발급하므로 `accessToken`/`refreshToken`이
/// 필수 필드다. 다만 누락 응답을 디코딩 실패로 만들지 않고 빈 문자열로 흡수한 뒤
/// `AuthRepository.loginByEmail()`이 유효성을 가드한다(`RegisterByIdPwResponseDTO`와 동일 계약).
public struct EmailLoginResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 로그인한 회원 ID (서버가 String 반환, Int로 흔들릴 수 있어 flexible 디코딩)
    public let memberId: String
    /// JWT 액세스 토큰
    public let accessToken: String
    /// JWT 리프레시 토큰
    public let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case memberId
        case accessToken
        case refreshToken
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
    }
}
