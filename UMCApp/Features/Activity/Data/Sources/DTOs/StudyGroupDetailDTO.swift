//
//  StudyGroupDetailDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

// MARK: - StudyGroupDetailDTO

/// 스터디 그룹 상세 응답 DTO
///
/// `GET /api/v1/study-groups/{groupId}`
///
/// 서버 식별자(`groupId`, `schoolId`, `challengerId`, `memberId`)는 전 레이어 `String` 통일
/// 규칙에 따라 `String` 으로 디코딩한다.
struct StudyGroupDetailDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let groupId: String
    let name: String
    let part: String
    let partDisplayName: String?
    let schools: [StudyGroupSchoolDTO]
    let createdAt: String
    let memberCount: Int
    let mentors: [StudyGroupChallengerDTO]
    let members: [StudyGroupChallengerDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case groupId
        case name
        case part
        case partDisplayName
        case schools
        case createdAt
        case memberCount
        case mentors
        case leader
        case members
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = container.decodeFlexibleStringOrNil(forKey: .groupId) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        partDisplayName = try container.decodeIfPresent(String.self, forKey: .partDisplayName)
        schools = try container.decodeIfPresent([StudyGroupSchoolDTO].self, forKey: .schools) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        memberCount = try container.decodeIntFlexibleIfPresent(forKey: .memberCount) ?? 0

        if let decodedMentors = try container.decodeIfPresent(
            [StudyGroupChallengerDTO].self,
            forKey: .mentors
        ) {
            mentors = decodedMentors
        } else if let legacyLeader = try container.decodeIfPresent(
            StudyGroupChallengerDTO.self,
            forKey: .leader
        ) {
            mentors = [legacyLeader]
        } else {
            mentors = []
        }
        members = try container.decodeIfPresent(
            [StudyGroupChallengerDTO].self,
            forKey: .members
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(name, forKey: .name)
        try container.encode(part, forKey: .part)
        try container.encodeIfPresent(partDisplayName, forKey: .partDisplayName)
        try container.encode(schools, forKey: .schools)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encode(mentors, forKey: .mentors)
        try container.encode(members, forKey: .members)
    }
}

// MARK: - StudyGroupSchoolDTO

/// 스터디 그룹 소속 학교 정보 DTO
struct StudyGroupSchoolDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let schoolId: String
    let schoolName: String
    let logoImageId: String?
    let totalStudyGroupCount: Int
    let totalMemberCount: Int

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case schoolId
        case schoolName
        case logoImageId
        case totalStudyGroupCount
        case totalMemberCount
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schoolId = container.decodeFlexibleStringOrNil(forKey: .schoolId) ?? ""
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        logoImageId = container.decodeFlexibleStringOrNil(forKey: .logoImageId)
        totalStudyGroupCount =
            try container.decodeIntFlexibleIfPresent(forKey: .totalStudyGroupCount) ?? 0
        totalMemberCount =
            try container.decodeIntFlexibleIfPresent(forKey: .totalMemberCount) ?? 0
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(logoImageId, forKey: .logoImageId)
        try container.encode(totalStudyGroupCount, forKey: .totalStudyGroupCount)
        try container.encode(totalMemberCount, forKey: .totalMemberCount)
    }
}

// MARK: - StudyGroupChallengerDTO

/// 스터디 그룹 소속 챌린저(멤버/리더) 정보 DTO
struct StudyGroupChallengerDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let challengerId: String
    let memberId: String
    let name: String
    let profileImageURL: String?
    let bestWorkbookPoint: Int?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case name
        case profileImageURL = "profileImageUrl"
        case bestWorkbookPoint
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = container.decodeFlexibleStringOrNil(forKey: .challengerId) ?? ""
        memberId = container.decodeFlexibleStringOrNil(forKey: .memberId) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        bestWorkbookPoint = try container.decodeIntFlexibleIfPresent(forKey: .bestWorkbookPoint)
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(challengerId, forKey: .challengerId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(bestWorkbookPoint, forKey: .bestWorkbookPoint)
    }
}

// MARK: - toDomain

extension StudyGroupDetailDTO {

    /// DTO 를 도메인 모델 ``StudyGroupInfo`` 로 변환한다.
    ///
    /// - Parameters:
    ///   - defaultGroupName: 그룹명이 비어 있을 때 대체할 이름
    ///   - bestWorkbookPointByMemberID: memberId → 베스트 워크북 점수 매핑 (없으면 DTO 내 점수 사용)
    /// - Returns: 변환된 ``StudyGroupInfo`` 도메인 모델
    func toDomain(
        defaultGroupName: String? = nil,
        bestWorkbookPointByMemberID: [String: Int] = [:]
    ) -> StudyGroupInfo {
        let partType = UMCPartType(apiValue: part) ?? .front(type: .ios)
        let university = schools.first?.schoolName ?? ""
        let parsedDate = StudyGroupDateParser.parse(createdAt) ?? Date()

        let mentorItems = mentors.map { mentor in
            makeMember(
                from: mentor,
                university: university,
                role: .leader,
                bestWorkbookPointByMemberID: bestWorkbookPointByMemberID
            )
        }

        let memberItems = members.map { member in
            makeMember(
                from: member,
                university: university,
                role: .member,
                bestWorkbookPointByMemberID: bestWorkbookPointByMemberID
            )
        }

        return StudyGroupInfo(
            serverID: groupId,
            name: name.isEmpty ? (defaultGroupName ?? "") : name,
            part: partType,
            createdDate: parsedDate,
            mentors: mentorItems,
            members: memberItems
        )
    }

    private func makeMember(
        from challenger: StudyGroupChallengerDTO,
        university: String,
        role: StudyGroupMember.MemberRole,
        bestWorkbookPointByMemberID: [String: Int]
    ) -> StudyGroupMember {
        StudyGroupMember(
            serverID: challenger.memberId,
            challengerID: challenger.challengerId.isEmpty ? nil : challenger.challengerId,
            memberID: challenger.memberId.isEmpty ? nil : challenger.memberId,
            name: challenger.name,
            university: university,
            profileImageURL: normalizedURL(challenger.profileImageURL),
            role: role,
            bestWorkbookPoint: bestWorkbookPointByMemberID[challenger.memberId]
                ?? challenger.bestWorkbookPoint
                ?? 0
        )
    }

    private func normalizedURL(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - StudyGroupDateParser

// TODO: Core 승격 시 ISO8601DateParser 등 범용 이름으로 변경 - [26.06.19] jaewon
/// ISO 8601 날짜 문자열 파서.
///
/// 밀리초(fractional seconds) 포함 포맷을 먼저 시도하고, 실패하면 표준 포맷으로 재시도한다.
/// ``CurriculumDTO`` 의 `parsedStartsAt` / `parsedEndsAt` 에서도 쓰여 DTO 범위를 넘어선다.
enum StudyGroupDateParser {
    static func parse(_ value: String) -> Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: value)
            ?? ISO8601DateFormatter.standard.date(from: value)
    }
}

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
