//
//  GisuDetailDTO.swift
//  HomeData
//
//  Created by euijjang97 on 7/9/26.
//

import Foundation
import UMCFoundation

/// 기수 상세 조회 응답 DTO
///
/// `GET /api/v1/gisu/{gisuId}` — 시즌 카드의 누적 활동일 계산에 필요한 시작일만 담는다.
/// `startAt`은 원시 문자열로 보관하고, 파싱은 `ServerDateTimeConverter`를 사용하는
/// 호출부(Repository)에서 수행한다.
public struct GisuDetailDTO: Codable {

    // MARK: - Property

    public let gisuId: String
    public let startAt: String

    private enum CodingKeys: String, CodingKey {
        case gisuId
        case startAt
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisuId = try container.decodeFlexibleString(forKey: .gisuId)
        startAt = try container.decode(String.self, forKey: .startAt)
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encode(startAt, forKey: .startAt)
    }
}
