//
//  StudyGroupDetailDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/18/26.
//

import Foundation

/// 스터디 그룹 상세 응답 DTO
///
/// `GET /api/v1/study-groups/{groupId}`
struct StudyGroupDetailDTO: Codable, Sendable, Equatable {
    let groupId: Int
    let name: String
    let part: String
    let partDisplayName: String?
    let schools: [StudyGroupSchoolDTO]
    let createdAt: String
    let memberCount: Int
    let mentors: [StudyGroupChallengerDTO]
    let members: [StudyGroupChallengerDTO]

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = try container.decodeIntFlexibleIfPresent(forKey: .groupId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        partDisplayName = try container.decodeIfPresent(String.self, forKey: .partDisplayName)
        schools = try container.decodeIfPresent([StudyGroupSchoolDTO].self, forKey: .schools) ?? []
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        memberCount = try container.decodeIntFlexibleIfPresent(forKey: .memberCount) ?? 0

        if let decodedMentors = try container.decodeIfPresent([StudyGroupChallengerDTO].self, forKey: .mentors) {
            mentors = decodedMentors
        } else if let legacyLeader = try container.decodeIfPresent(StudyGroupChallengerDTO.self, forKey: .leader) {
            mentors = [legacyLeader]
        } else {
            mentors = []
        }
        members = try container.decodeIfPresent([StudyGroupChallengerDTO].self, forKey: .members) ?? []
    }

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

/// 스터디 그룹 소속 학교 정보 DTO
struct StudyGroupSchoolDTO: Codable, Sendable, Equatable {
    let schoolId: Int
    let schoolName: String
    let logoImageId: String?
    let totalStudyGroupCount: Int
    let totalMemberCount: Int

    private enum CodingKeys: String, CodingKey {
        case schoolId
        case schoolName
        case logoImageId
        case totalStudyGroupCount
        case totalMemberCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schoolId = try container.decodeIntFlexibleIfPresent(forKey: .schoolId) ?? 0
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        logoImageId = try container.decodeIfPresent(String.self, forKey: .logoImageId)
        totalStudyGroupCount = try container.decodeIntFlexibleIfPresent(forKey: .totalStudyGroupCount) ?? 0
        totalMemberCount = try container.decodeIntFlexibleIfPresent(forKey: .totalMemberCount) ?? 0
    }
}

/// 스터디 그룹 소속 챌린저(멤버/리더) 정보 DTO
struct StudyGroupChallengerDTO: Codable, Sendable, Equatable {
    let challengerId: Int
    let memberId: Int
    let name: String
    let profileImageUrl: String?
    let bestWorkbookPoint: Int?

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case name
        case profileImageUrl
        case bestWorkbookPoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeIntFlexibleIfPresent(forKey: .challengerId) ?? 0
        memberId = try container.decodeIntFlexibleIfPresent(forKey: .memberId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        bestWorkbookPoint = try container.decodeIntFlexibleIfPresent(forKey: .bestWorkbookPoint)
    }
}

extension StudyGroupDetailDTO {
    /// DTO를 도메인 모델 `StudyGroupInfo`로 변환합니다.
    ///
    /// - Parameters:
    ///   - defaultGroupName: 그룹명이 비어 있을 때 대체할 이름
    ///   - bestWorkbookPointByMemberID: memberId → 베스트 워크북 점수 매핑 (없으면 DTO 내 점수 사용)
    /// - Returns: 변환된 `StudyGroupInfo` 도메인 모델
    func toDomain(
        defaultGroupName: String? = nil,
        bestWorkbookPointByMemberID: [Int: Int] = [:]
    ) -> StudyGroupInfo {
        let partType = UMCPartType(apiValue: part) ?? .front(type: .ios)
        let university = schools.first?.schoolName ?? ""
        let parsedDate = Self.parseISO8601Date(createdAt) ?? Date()

        let mentorItems = mentors.map { mentor in
            StudyGroupMember(
                serverID: String(mentor.memberId),
                challengerID: mentor.challengerId,
                memberID: mentor.memberId,
                name: mentor.name,
                university: university,
                profileImageURL: normalizedURL(mentor.profileImageUrl),
                role: .leader,
                bestWorkbookPoint: bestWorkbookPointByMemberID[mentor.memberId]
                    ?? mentor.bestWorkbookPoint
                    ?? 0
            )
        }

        let memberItems = members.map { member in
            StudyGroupMember(
                serverID: String(member.memberId),
                challengerID: member.challengerId,
                memberID: member.memberId,
                name: member.name,
                university: university,
                profileImageURL: normalizedURL(member.profileImageUrl),
                role: .member,
                bestWorkbookPoint: bestWorkbookPointByMemberID[member.memberId]
                    ?? member.bestWorkbookPoint
                    ?? 0
            )
        }

        return StudyGroupInfo(
            serverID: String(groupId),
            name: name.isEmpty ? (defaultGroupName ?? "") : name,
            part: partType,
            createdDate: parsedDate,
            mentors: mentorItems,
            members: memberItems
        )
    }

    private func normalizedURL(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// ISO 8601 날짜 문자열을 Date로 파싱합니다.
    ///
    /// 밀리초 포함 포맷을 먼저 시도하고, 실패하면 표준 포맷으로 재시도합니다.
    /// - Parameter value: ISO 8601 형식의 날짜 문자열
    /// - Returns: 파싱 성공 시 Date, 실패 시 nil
    private static func parseISO8601Date(_ value: String) -> Date? {
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
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
