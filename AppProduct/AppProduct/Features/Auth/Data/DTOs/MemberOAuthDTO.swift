//
//  MemberOAuthDTO.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

/// 회원 OAuth 연동 정보 API 응답 DTO
struct MemberOAuthDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// OAuth 연동 ID
    let memberOAuthId: Int
    /// 회원 ID (서버 응답 String 기준)
    let memberId: String
    /// OAuth 제공자 (KAKAO, APPLE)
    let provider: OAuthProvider

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case memberOAuthId
        case memberId
        case provider
    }

    // MARK: - Init

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        memberOAuthId = try Self.decodeFlexibleInt(
            from: container,
            forKey: .memberOAuthId
        )
        memberId = try Self.decodeFlexibleString(
            from: container,
            forKey: .memberId
        )
        provider = try container.decode(OAuthProvider.self, forKey: .provider)
    }

    // MARK: - Mapping

    /// Domain 모델로 변환
    func toDomain() -> MemberOAuth {
        MemberOAuth(
            memberOAuthId: memberOAuthId,
            memberId: memberId,
            provider: provider
        )
    }
}

// MARK: - Private Helpers

private extension MemberOAuthDTO {
    private static func decodeFlexibleInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try? container.decode(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: container.codingPath + [key],
                debugDescription: "\(key.stringValue)는 Int 또는 숫자 문자열이어야 합니다."
            )
        )
    }

    /// 서버가 Int 또는 String 어느 쪽으로도 응답할 수 있는 ID 류 필드를 String 으로 통일 디코딩한다.
    private static func decodeFlexibleString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? container.decode(Int.self, forKey: key) {
            return String(intValue)
        }

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: container.codingPath + [key],
                debugDescription: "\(key.stringValue)는 String 또는 Int 이어야 합니다."
            )
        )
    }
}
