//
//  MyStudyGroupsPageDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import UMCFoundation
import ActivityDomain

// MARK: - MyStudyGroupsPageDTO

/// 스터디 그룹 상세 목록 페이지 DTO (커서 기반 페이지네이션)
///
/// `GET /api/v1/study-groups`
///
/// 도메인 ``StudyGroupDetailsPage/content`` 가 `[StudyGroupInfo]`(풀 정보)이므로,
/// 페이지 항목은 ``StudyGroupDetailDTO``(풀 그룹 상세)로 디코딩한다.
/// 서버가 `cursor` 래핑 / `content` 키 / `studyGroups` 키 중 어느 포맷으로 응답해도
/// 흡수하도록 유연하게 디코딩한다. 커서(`nextCursor`)는 `String` 으로 통일한다.
struct MyStudyGroupsPageDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let studyGroups: [StudyGroupDetailDTO]
    let nextCursor: String?
    let hasNext: Bool

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case cursor
        case studyGroups
        case content
        case nextCursor
        case hasNext
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 서버가 cursor 래핑 포맷으로 응답하는 경우
        if let cursor = try container.decodeIfPresent(
            MyStudyGroupsCursorDTO.self,
            forKey: .cursor
        ) {
            studyGroups = cursor.content
            nextCursor = cursor.nextCursor
            hasNext = cursor.hasNext
            return
        }

        // content 키를 직접 포함하는 flat 포맷인 경우
        if let content = try container.decodeIfPresent(
            [StudyGroupDetailDTO].self,
            forKey: .content
        ) {
            studyGroups = content
            nextCursor = container.decodeFlexibleStringOrNil(forKey: .nextCursor)
            hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
            return
        }

        // studyGroups 키를 직접 포함하는 포맷 (최종 fallback)
        studyGroups = try container.decodeIfPresent(
            [StudyGroupDetailDTO].self,
            forKey: .studyGroups
        ) ?? []
        nextCursor = container.decodeFlexibleStringOrNil(forKey: .nextCursor)
        hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(studyGroups, forKey: .studyGroups)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
        try container.encode(hasNext, forKey: .hasNext)
    }

    // MARK: - toDomain

    /// DTO 를 도메인 모델 ``StudyGroupDetailsPage`` 로 변환한다.
    func toDomain() -> StudyGroupDetailsPage {
        StudyGroupDetailsPage(
            content: studyGroups.map { $0.toDomain() },
            hasNext: hasNext,
            nextCursor: nextCursor
        )
    }
}

// MARK: - MyStudyGroupsCursorDTO

/// `cursor` 래핑 포맷의 내부 페이지 DTO
private struct MyStudyGroupsCursorDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let content: [StudyGroupDetailDTO]
    let nextCursor: String?
    let hasNext: Bool

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case content
        case nextCursor
        case hasNext
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(
            [StudyGroupDetailDTO].self,
            forKey: .content
        ) ?? []
        nextCursor = container.decodeFlexibleStringOrNil(forKey: .nextCursor)
        hasNext = try container.decodeBoolFlexibleIfPresent(forKey: .hasNext) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(nextCursor, forKey: .nextCursor)
        try container.encode(hasNext, forKey: .hasNext)
    }
}
