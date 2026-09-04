//
//  ScheduleParticipantDTO.swift
//  HomeData
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HomeDomain
import UMCFoundation

/// V2 일정 응답의 `participants[]` 항목 DTO
///
/// - SeeAlso: ``HomeDomain/ScheduleParticipant``
public struct ScheduleParticipantDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 멤버 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let memberId: String
    public let name: String
    public let nickname: String
    /// 프로필 이미지 URL (서버가 `null` 로 내려줄 수 있음)
    public let profileImageUrl: String?
    /// 학교 식별자. 서버 정수를 핵심 규칙 #2에 따라 `String`으로 보존한다.
    public let schoolId: String
    public let schoolName: String

    private enum CodingKeys: String, CodingKey {
        case memberId
        case name
        case nickname
        case profileImageUrl
        case schoolId
        case schoolName
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
    }
}

// MARK: - Domain 변환

extension ScheduleParticipantDTO {

    /// DTO → 도메인 변환. 프로필 이미지가 없으면 빈 문자열로 정규화한다.
    func toDomain() -> ScheduleParticipant {
        ScheduleParticipant(
            memberId: memberId,
            name: name,
            nickname: nickname,
            profileImageUrl: profileImageUrl ?? "",
            schoolId: schoolId,
            schoolName: schoolName
        )
    }
}
