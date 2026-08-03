//
//  StudyMemberSubmission.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation
import UMCFoundation

// MARK: - StudyMemberSubmission

/// 스터디원 1명의 주차별 워크북 제출 현황
///
/// 서버 `GET /api/v2/curriculums/workbook-submissions` 응답의 행 단위입니다.
/// **행은 제출물이 아니라 스터디원**이며, 주차는 ``weeks`` 배열에 담깁니다
/// (커서가 `studyGroupMemberId` 라서 주차를 행으로 펼치면 커서 의미가 깨짐).
///
/// 아직 워크북을 배포받지 않은 인원도 결과에 포함되며, 그 주차는
/// ``WeeklySubmission/challengerWorkbookId`` 가 `nil` 이고 상태가
/// ``ChallengerWorkbookStatus/notSubmitted`` 입니다.
///
/// 주차별 카드 UI 로 펼치려면 ``managementItems`` 로 flatMap 합니다.
public struct StudyMemberSubmission: Identifiable, Equatable, Sendable {

    // MARK: - Property

    /// 스터디 그룹 멤버 식별자 — 목록 커서이자 행 식별자 (서버 응답)
    public let studyGroupMemberId: String
    /// 멤버 식별자 (서버 응답)
    public let memberId: String
    /// 실명 — 운영진이 인원을 식별하는 기준
    public let memberName: String
    /// 닉네임 (서버가 주지 않거나 미설정이면 `nil`)
    public let nickname: String?
    /// 소속 학교명
    public let schoolName: String?
    /// 프로필 이미지 주소
    public let profileImageURL: String?
    /// 스터디 그룹 식별자 (서버 응답)
    public let studyGroupId: String
    /// 스터디 그룹명
    public let studyGroupName: String
    /// 파트 — 서버가 아는 값이면 매핑되고, 모르는 값이면 `nil`
    public let part: UMCPartType?
    /// 파트 표시 라벨
    ///
    /// 서버 값이 매핑되면 ``UMCPartType/name``, 매핑되지 않으면 서버 원문을 그대로 보존합니다.
    /// ``part`` 만 두면 미매핑 값의 원문이 사라져 화면에서 파트를 아예 못 읽게 됩니다.
    public let partLabel: String
    /// 주차별 제출 현황 (요청에서 주차를 지정하지 않았으면 전체 주차)
    public let weeks: [WeeklySubmission]

    // MARK: - Identifiable

    public var id: String { studyGroupMemberId }

    // MARK: - Initializer

    public init(
        studyGroupMemberId: String,
        memberId: String,
        memberName: String,
        nickname: String? = nil,
        schoolName: String? = nil,
        profileImageURL: String? = nil,
        studyGroupId: String,
        studyGroupName: String,
        part: UMCPartType?,
        partLabel: String,
        weeks: [WeeklySubmission]
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
        self.partLabel = partLabel
        self.weeks = weeks
    }

    // MARK: - Computed Property

    /// 목록에 표시할 이름
    ///
    /// 닉네임이 있으면 닉네임, 없거나 공백뿐이면 실명으로 폴백합니다.
    public var displayName: String {
        guard let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            return memberName
        }
        return nickname
    }

    // MARK: - Function

    /// 주차별 카드 행으로 펼친다.
    ///
    /// 서버가 주차를 행이 아니라 배열로 내려주므로, 주차 단위 카드 UI 는 이 변환을 거칩니다.
    /// 정렬은 주차 번호 오름차순이며, 숫자로 읽히지 않는 주차는 뒤로 보냅니다.
    public var managementItems: [StudyManagementItem] {
        weeks
            .sorted { lhs, rhs in
                let lhsNo = Int(lhs.weekNo) ?? Int.max
                let rhsNo = Int(rhs.weekNo) ?? Int.max
                if lhsNo == rhsNo { return lhs.weekNo < rhs.weekNo }
                return lhsNo < rhsNo
            }
            .map { StudyManagementItem(submission: self, week: $0) }
    }
}

// MARK: - WeeklySubmission

/// 스터디원 1명의 특정 주차 제출 현황
public struct WeeklySubmission: Identifiable, Equatable, Sendable {

    // MARK: - Property

    /// 주차 번호 (서버 응답)
    public let weekNo: String
    /// 주차 커리큘럼 식별자 (서버 응답)
    public let weeklyCurriculumId: String
    /// 챌린저 워크북 식별자 — `nil` 이면 워크북 미배포라 상세로 이동할 수 없습니다.
    public let challengerWorkbookId: String?
    /// 워크북 평가 상태
    public let status: ChallengerWorkbookStatus
    /// 베스트 워크북 여부 — ``status`` 와 독립입니다 (통과이면서 베스트일 수 있음).
    public let isBest: Bool

    // MARK: - Identifiable

    public var id: String { weeklyCurriculumId }

    // MARK: - Initializer

    public init(
        weekNo: String,
        weeklyCurriculumId: String,
        challengerWorkbookId: String? = nil,
        status: ChallengerWorkbookStatus,
        isBest: Bool = false
    ) {
        self.weekNo = weekNo
        self.weeklyCurriculumId = weeklyCurriculumId
        self.challengerWorkbookId = challengerWorkbookId
        self.status = status
        self.isBest = isBest
    }
}

// MARK: - StudyMemberSubmissionPage

/// 스터디원 제출 현황 페이지 (커서 기반 페이지네이션)
///
/// 커서는 직전 페이지 마지막 ``StudyMemberSubmission/studyGroupMemberId`` 입니다.
public struct StudyMemberSubmissionPage: Equatable, Sendable {

    // MARK: - Property

    public let content: [StudyMemberSubmission]
    public let hasNext: Bool

    /// 다음 페이지 커서 (서버 응답, 마지막 페이지면 `nil`)
    public let nextCursor: String?

    // MARK: - Initializer

    public init(
        content: [StudyMemberSubmission],
        hasNext: Bool,
        nextCursor: String?
    ) {
        self.content = content
        self.hasNext = hasNext
        self.nextCursor = nextCursor
    }
}
