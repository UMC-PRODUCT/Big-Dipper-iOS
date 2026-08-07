//
//  StudyGroupNamesDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

// MARK: - StudyGroupNamesDTO

/// 관리 가능한 스터디 그룹 이름 목록 DTO
///
/// `GET /api/v1/study-groups/names`
///
/// 그룹 필터 드롭다운처럼 목록 전체가 필요한 화면 전용이라 페이지네이션이 없습니다.
struct StudyGroupNamesDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let studyGroups: [StudyGroupNameDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case studyGroups
    }

    // MARK: - Init

    init(studyGroups: [StudyGroupNameDTO]) {
        self.studyGroups = studyGroups
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studyGroups = try container.decodeIfPresent(
            [StudyGroupNameDTO].self,
            forKey: .studyGroups
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(studyGroups, forKey: .studyGroups)
    }

    // MARK: - toDomain

    func toDomain() -> [StudyGroupName] {
        studyGroups.map { $0.toDomain() }
    }
}

// MARK: - StudyGroupNameDTO

/// 스터디 그룹 이름 항목 DTO
struct StudyGroupNameDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let groupId: String
    let name: String

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case groupId
        case name
    }

    // MARK: - Init

    init(groupId: String, name: String) {
        self.groupId = groupId
        self.name = name
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = container.decodeFlexibleStringOrEmpty(forKey: .groupId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(name, forKey: .name)
    }

    // MARK: - toDomain

    func toDomain() -> StudyGroupName {
        StudyGroupName(groupId: groupId, name: name)
    }
}
