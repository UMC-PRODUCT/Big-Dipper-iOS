//
//  StudyMemberSubmissionDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import ActivityDomain
import UMCFoundation

// MARK: - StudyMemberSubmissionPageDTO

/// 스터디원 제출 현황 페이지 DTO (커서 기반 페이지네이션)
///
/// `GET /api/v2/curriculums/workbook-submissions` 의
/// `CursorResponse<StudyMemberSubmissionResponse>` 에 대응합니다.
/// 커서(`nextCursor`)는 서버가 `studyGroupMemberId` 를 그대로 echo 하므로 `String` 으로 통일합니다.
struct StudyMemberSubmissionPageDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let content: [StudyMemberSubmissionDTO]
    let nextCursor: String?
    let hasNext: Bool

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case content
        case nextCursor
        case hasNext
    }

    // MARK: - Init

    init(
        content: [StudyMemberSubmissionDTO],
        nextCursor: String?,
        hasNext: Bool
    ) {
        self.content = content
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(
            [StudyMemberSubmissionDTO].self,
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

    // MARK: - toDomain

    func toDomain() -> StudyMemberSubmissionPage {
        StudyMemberSubmissionPage(
            content: content.map { $0.toDomain() },
            hasNext: hasNext,
            nextCursor: nextCursor
        )
    }
}

// MARK: - StudyMemberSubmissionDTO

/// 스터디원 1명의 제출 현황 행 DTO
///
/// 행 단위는 제출물이 아니라 **스터디원**이며, 주차는 ``weeks`` 배열에 담깁니다.
struct StudyMemberSubmissionDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let studyGroupMemberId: String
    let memberId: String
    let memberName: String
    let nickname: String?
    let schoolName: String?
    let profileImageURL: String?
    let studyGroupId: String
    let studyGroupName: String
    /// 서버 `ChallengerPart` 원문 (예: `IOS`)
    let part: String
    let weeks: [WeeklySubmissionDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case studyGroupMemberId
        case memberId
        case memberName
        case nickname
        case schoolName
        case profileImageURL = "profileImageUrl"
        case studyGroupId
        case studyGroupName
        case part
        case weeks
    }

    // MARK: - Init

    init(
        studyGroupMemberId: String,
        memberId: String,
        memberName: String,
        nickname: String?,
        schoolName: String?,
        profileImageURL: String?,
        studyGroupId: String,
        studyGroupName: String,
        part: String,
        weeks: [WeeklySubmissionDTO]
    ) {
        self.studyGroupMemberId = studyGroupMemberId
        self.memberId = memberId
        self.memberName = memberName
        self.nickname = nickname
        self.schoolName = schoolName
        self.profileImageURL = profileImageURL
        self.studyGroupId = studyGroupId
        self.studyGroupName = studyGroupName
        self.part = part
        self.weeks = weeks
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studyGroupMemberId = container.decodeFlexibleStringOrEmpty(forKey: .studyGroupMemberId)
        memberId = container.decodeFlexibleStringOrEmpty(forKey: .memberId)
        memberName = try container.decodeIfPresent(String.self, forKey: .memberName) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        studyGroupId = container.decodeFlexibleStringOrEmpty(forKey: .studyGroupId)
        studyGroupName = try container.decodeIfPresent(String.self, forKey: .studyGroupName) ?? ""
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        weeks = try container.decodeIfPresent([WeeklySubmissionDTO].self, forKey: .weeks) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(studyGroupMemberId, forKey: .studyGroupMemberId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(memberName, forKey: .memberName)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(schoolName, forKey: .schoolName)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(studyGroupId, forKey: .studyGroupId)
        try container.encode(studyGroupName, forKey: .studyGroupName)
        try container.encode(part, forKey: .part)
        try container.encode(weeks, forKey: .weeks)
    }

    // MARK: - toDomain

    /// 도메인 행으로 변환한다.
    ///
    /// 파트는 서버 원문을 ``UMCPartType`` 으로 해석하되, 모르는 값이면 `nil` 로 두고 **원문을
    /// 라벨로 보존**한다. 원문을 버리면 화면에서 파트를 아예 읽을 수 없게 된다.
    func toDomain() -> StudyMemberSubmission {
        let partType = UMCPartType(apiValue: part)

        return StudyMemberSubmission(
            studyGroupMemberId: studyGroupMemberId,
            memberId: memberId,
            memberName: memberName,
            nickname: nickname,
            schoolName: schoolName,
            profileImageURL: profileImageURL,
            studyGroupId: studyGroupId,
            studyGroupName: studyGroupName,
            part: partType,
            partLabel: partType?.name ?? part,
            weeks: weeks.map { $0.toDomain() }
        )
    }
}

// MARK: - WeeklySubmissionDTO

/// 특정 주차의 제출 현황 DTO
///
/// `challengerWorkbookId` 가 없으면 워크북 미배포이며, 그때 `status` 는 `NOT_SUBMITTED` 입니다.
struct WeeklySubmissionDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let weekNo: String
    let weeklyCurriculumId: String
    let challengerWorkbookId: String?
    let status: ChallengerWorkbookStatus
    let isBest: Bool

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case weekNo
        case weeklyCurriculumId
        case challengerWorkbookId
        case status
        case isBest
    }

    // MARK: - Init

    init(
        weekNo: String,
        weeklyCurriculumId: String,
        challengerWorkbookId: String?,
        status: ChallengerWorkbookStatus,
        isBest: Bool
    ) {
        self.weekNo = weekNo
        self.weeklyCurriculumId = weeklyCurriculumId
        self.challengerWorkbookId = challengerWorkbookId
        self.status = status
        self.isBest = isBest
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekNo = container.decodeFlexibleStringOrEmpty(forKey: .weekNo)
        weeklyCurriculumId = container.decodeFlexibleStringOrEmpty(forKey: .weeklyCurriculumId)
        challengerWorkbookId = container.decodeFlexibleStringOrNil(forKey: .challengerWorkbookId)
        // 상태 enum 이 자체 `init(from:)` 에서 모르는 값을 `.unknown` 으로 흡수하므로,
        // 여기서 문자열로 먼저 꺼내지 않고 그대로 디코딩한다.
        status = try container.decodeIfPresent(
            ChallengerWorkbookStatus.self,
            forKey: .status
        ) ?? .unknown
        isBest = try container.decodeBoolFlexibleIfPresent(forKey: .isBest) ?? false
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weekNo, forKey: .weekNo)
        try container.encode(weeklyCurriculumId, forKey: .weeklyCurriculumId)
        try container.encodeIfPresent(challengerWorkbookId, forKey: .challengerWorkbookId)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(isBest, forKey: .isBest)
    }

    // MARK: - toDomain

    func toDomain() -> WeeklySubmission {
        WeeklySubmission(
            weekNo: weekNo,
            weeklyCurriculumId: weeklyCurriculumId,
            challengerWorkbookId: challengerWorkbookId,
            status: status,
            isBest: isBest
        )
    }
}
