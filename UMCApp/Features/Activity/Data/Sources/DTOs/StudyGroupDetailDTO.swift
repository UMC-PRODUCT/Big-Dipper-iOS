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
/// `GET /api/v1/study-groups/{studyGroupId}` · `GET /api/v1/study-groups/managed`
///
/// 서버 `StudyGroupResponse` 계약에 맞춘 키만 디코딩한다. 서버 식별자(`studyGroupId`,
/// `memberId`)는 정수로 내려오지만 전 레이어 `String` 통일 규칙에 따라 `String` 으로 받는다.
///
/// - Note: 서버가 함께 내려주는 `gisuId` 는 도메인에서 쓰지 않아 디코딩하지 않는다.
struct StudyGroupDetailDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let studyGroupId: String
    let name: String
    let studyPart: String
    let createdAt: String
    let mentors: [StudyGroupChallengerDTO]
    let members: [StudyGroupChallengerDTO]

    // MARK: - Computed Property

    /// 그룹에 속한 모든 멤버(파트장 + 스터디원)의 `memberId` — 빈 값은 제외한다.
    ///
    /// 서버가 주지 않는 `challengerId`·`nickname` 을 멤버 프로필로 보강할 때 조회 대상 목록으로 쓴다.
    var allMemberIDs: [String] {
        (mentors + members)
            .map(\.memberId)
            .filter { !$0.isEmpty }
    }

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case studyGroupId
        case name
        case studyPart
        case createdAt
        case mentors
        case members
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studyGroupId = container.decodeFlexibleStringOrNil(forKey: .studyGroupId) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        studyPart = try container.decodeIfPresent(String.self, forKey: .studyPart) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        mentors = try container.decodeIfPresent(
            [StudyGroupChallengerDTO].self,
            forKey: .mentors
        ) ?? []
        members = try container.decodeIfPresent(
            [StudyGroupChallengerDTO].self,
            forKey: .members
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(studyGroupId, forKey: .studyGroupId)
        try container.encode(name, forKey: .name)
        try container.encode(studyPart, forKey: .studyPart)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(mentors, forKey: .mentors)
        try container.encode(members, forKey: .members)
    }
}

// MARK: - StudyGroupChallengerDTO

/// 스터디 그룹 소속 챌린저(파트장/스터디원) 정보 DTO
///
/// 서버 `StudyGroupMemberResponse` 계약에 맞춘 키만 디코딩한다. 응답에 함께 오는 `schoolId` 는
/// 도메인에서 쓰지 않아 생략한다.
struct StudyGroupChallengerDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let memberId: String
    let memberName: String
    let schoolName: String
    let profileImageURL: String?
    /// 베스트 워크북 표시 점수.
    ///
    /// - Note: 서버가 **아직 내려주지 않는 필드**라 실제 응답에서는 항상 `nil` 이며,
    ///   ``StudyGroupDetailDTO/toDomain(defaultGroupName:supplementsByMemberID:)`` 이 `0` 으로
    ///   폴백한다. 서버가 멤버별 값을 응답에 포함하면 코드 변경 없이 그대로 반영되도록 자리를
    ///   유지한다.
    let bestWorkbookPoint: Int?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case memberId
        case memberName
        case schoolName
        case profileImageURL = "profileImageUrl"
        case bestWorkbookPoint
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = container.decodeFlexibleStringOrNil(forKey: .memberId) ?? ""
        memberName = try container.decodeIfPresent(String.self, forKey: .memberName) ?? ""
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        bestWorkbookPoint = try container.decodeIntFlexibleIfPresent(forKey: .bestWorkbookPoint)
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(memberName, forKey: .memberName)
        try container.encode(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encodeIfPresent(bestWorkbookPoint, forKey: .bestWorkbookPoint)
    }
}

// MARK: - StudyGroupMemberSupplement

/// 스터디 그룹 응답에 없는 멤버 정보를 멤버 프로필에서 보강한 값.
///
/// 서버 `StudyGroupMemberResponse` 는 `challengerId` 와 `nickname` 을 주지 않으므로
/// ``StudyRepository`` 가 `GET /api/v1/member/profile/{memberId}` 로 해석해 채운다.
/// 해석에 실패한 멤버는 매핑에서 빠지고, 두 값 모두 `nil` 로 남는다.
struct StudyGroupMemberSupplement: Sendable, Equatable {

    // MARK: - Property

    let challengerID: String?
    let nickname: String?

    // MARK: - Init

    init(challengerID: String?, nickname: String?) {
        self.challengerID = challengerID
        self.nickname = nickname
    }
}

// MARK: - toDomain

extension StudyGroupDetailDTO {

    /// DTO 를 도메인 모델 ``StudyGroupInfo`` 로 변환한다.
    ///
    /// - Note: `challengerID`·`nickname` 은 스터디 그룹 응답에 없어
    ///   `supplementsByMemberID` 로만 채워진다. 보강 값이 없으면 두 필드는 `nil` 로 남는다.
    ///   특히 `challengerID` 는 `memberId` 로 대체하지 않는다 — 챌린저와 멤버는 서로 다른
    ///   식별자라 대체하면 잘못된 대상으로 서버를 호출하게 된다.
    ///
    /// - Parameters:
    ///   - defaultGroupName: 그룹명이 비어 있을 때 대체할 이름
    ///   - supplementsByMemberID: `memberId` → 멤버 프로필에서 해석한 보강 정보
    /// - Returns: 변환된 ``StudyGroupInfo`` 도메인 모델
    func toDomain(
        defaultGroupName: String? = nil,
        supplementsByMemberID: [String: StudyGroupMemberSupplement] = [:]
    ) -> StudyGroupInfo {
        let partType = UMCPartType(apiValue: studyPart) ?? .front(type: .ios)
        let parsedDate = StudyGroupDateParser.parse(createdAt) ?? Date()

        let mentorItems = mentors.map { mentor in
            makeMember(
                from: mentor,
                role: .leader,
                supplement: supplementsByMemberID[mentor.memberId]
            )
        }

        let memberItems = members.map { member in
            makeMember(
                from: member,
                role: .member,
                supplement: supplementsByMemberID[member.memberId]
            )
        }

        return StudyGroupInfo(
            serverID: studyGroupId,
            name: name.isEmpty ? (defaultGroupName ?? "") : name,
            part: partType,
            createdDate: parsedDate,
            mentors: mentorItems,
            members: memberItems
        )
    }

    private func makeMember(
        from challenger: StudyGroupChallengerDTO,
        role: StudyGroupMember.MemberRole,
        supplement: StudyGroupMemberSupplement?
    ) -> StudyGroupMember {
        StudyGroupMember(
            serverID: challenger.memberId,
            challengerID: supplement?.challengerID,
            memberID: challenger.memberId.isEmpty ? nil : challenger.memberId,
            name: challenger.memberName,
            nickname: supplement?.nickname,
            university: challenger.schoolName,
            profileImageURL: normalizedURL(challenger.profileImageURL),
            role: role,
            bestWorkbookPoint: challenger.bestWorkbookPoint ?? 0
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
