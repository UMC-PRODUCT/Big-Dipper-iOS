//
//  StudyGroupNameItemDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 스터디 그룹 단일 항목 DTO
///
/// `studyGroupId` / `groupId` / `id` 중 하나의 키를 유연하게 디코딩합니다.
/// `/api/v1/study-groups/managed` 응답에서 사용합니다.
struct StudyGroupNameItemDTO: Codable, Sendable, Equatable {
    let groupId: Int
    let name: String
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case studyGroupId
        case groupId
        case id
        case name
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 서버 응답 포맷에 따라 studyGroupId / groupId / id 키를 순서대로 시도
        groupId = try container.decodeIntFlexibleIfPresent(forKey: .studyGroupId)
            ?? container.decodeIntFlexibleIfPresent(forKey: .groupId)
            ?? container.decodeIntFlexibleIfPresent(forKey: .id)
            ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .studyGroupId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

private extension KeyedDecodingContainer {
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }
}
