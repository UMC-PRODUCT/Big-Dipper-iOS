//
//  ChallengerProfileDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation

/// 챌린저 프로필 응답 DTO (포인트 히스토리 전용 부분 디코딩)
///
/// `GET /api/v1/challenger/{challengerId}`
///
/// - Note: 레거시는 멤버 관리 포인트 히스토리를 MyPage `ChallengerMemberDTO` 전체로
///   디코딩했습니다. 본 모듈의 ``MemberRepository/fetchPointHistory(challengerId:)`` 는
///   `challengerPoints` 만 쓰므로 그 필드만 디코딩합니다. MyPage 모듈에 기대지 않고
///   챌린저 엔드포인트를 이식하려는 것입니다(나머지 응답 필드는 무시).
/// - Note: 레거시 `ChallengerMemberDTO` 와 동일하게, `challengerPoints` 가 비어 있으면 루트
///   `points` 키를 폴백으로 사용합니다(서버가 두 키 형식을 혼용하므로 히스토리 누락 방지).
struct ChallengerProfileDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerPoints: [MemberManagementPointDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerPoints
        case fallbackPoints = "points"
    }

    // MARK: - Init

    init(challengerPoints: [MemberManagementPointDTO]) {
        self.challengerPoints = challengerPoints
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let primary = try container.decodeIfPresent(
            [MemberManagementPointDTO].self,
            forKey: .challengerPoints
        ) ?? []
        let fallback = try container.decodeIfPresent(
            [MemberManagementPointDTO].self,
            forKey: .fallbackPoints
        ) ?? []
        challengerPoints = primary.isEmpty ? fallback : primary
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerPoints, forKey: .challengerPoints)
    }
}
