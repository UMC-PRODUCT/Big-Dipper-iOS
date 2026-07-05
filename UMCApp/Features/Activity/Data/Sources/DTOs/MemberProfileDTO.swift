//
//  MemberProfileDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/24/26.
//

import Foundation
import UMCFoundation
// MARK: - MemberProfileDTO

/// 멤버 프로필 응답 DTO (챌린저 ID 해석 전용)
///
/// `GET /api/v1/member/profile/{memberId}`
///
/// ``StudyRepository/resolveChallengerId(memberId:preferredGeneration:)`` 가
/// `challengerRecords` 만 사용하므로 본 DTO 는 해당 필드만 디코딩한다(나머지 응답 필드는
/// `Codable` 이 무시). 서버 식별자는 전 레이어 `String` 통일 규칙에 따라 `String` 으로 디코딩한다.
struct MemberProfileDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerRecords: [MemberChallengerRecordDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerRecords
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerRecords = try container.decodeIfPresent(
            [MemberChallengerRecordDTO].self,
            forKey: .challengerRecords
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - MemberChallengerRecordDTO

/// 멤버의 기수별 챌린저 활동 레코드 DTO (챌린저 ID 해석에 필요한 필드만)
struct MemberChallengerRecordDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerId: String
    let memberId: String
    let gisu: Int
    let gisuId: String

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisu
        case gisuId
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = container.decodeFlexibleStringOrNil(forKey: .challengerId) ?? ""
        memberId = container.decodeFlexibleStringOrNil(forKey: .memberId) ?? ""
        gisu = try container.decodeIntFlexibleIfPresent(forKey: .gisu) ?? 0
        gisuId = container.decodeFlexibleStringOrNil(forKey: .gisuId) ?? ""
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
    }
}
