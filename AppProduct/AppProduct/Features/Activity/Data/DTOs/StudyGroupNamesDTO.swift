//
//  StudyGroupNamesDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 로그인한 유저의 스터디 그룹 id/이름 목록 응답 DTO
///
/// `GET /api/v1/study-groups/names`
struct StudyGroupNamesDTO: Codable, Sendable, Equatable {
    let studyGroups: [StudyGroupNameItemDTO]
}

/// 스터디 그룹 단일 항목 DTO
///
/// `groupId` 또는 `id` 키 중 하나를 유연하게 디코딩합니다.
struct StudyGroupNameItemDTO: Codable, Sendable, Equatable {
    let groupId: Int
    let name: String
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case groupId
        case id
        case name
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 서버 응답 포맷에 따라 groupId 또는 id 키를 순서대로 시도
        groupId = try container.decodeIntFlexibleIfPresent(forKey: .groupId)
            ?? container.decodeIntFlexibleIfPresent(forKey: .id)
            ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

extension StudyGroupNamesDTO {
    /// DTO 목록을 도메인 모델 `StudyGroupItem` 배열로 변환합니다.
    ///
    /// 항상 `.all` 항목을 첫 번째 요소로 포함하여 반환합니다.
    /// - Returns: `.all` + 스터디 그룹 목록 순서의 `StudyGroupItem` 배열
    func toDomain() -> [StudyGroupItem] {
        let groups = studyGroups.map { item in
            StudyGroupItem(
                serverID: String(item.groupId),
                name: item.name,
                iconName: "person.2.fill",
                part: nil
            )
        }
        return [.all] + groups
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
