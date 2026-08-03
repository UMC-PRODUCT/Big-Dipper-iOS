//
//  StudyManagementItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 운영진 스터디 제출 현황 카드용 행 모델
///
/// 스터디원 1명 × 주차 1개를 하나의 카드로 표현합니다.
/// 서버는 주차를 행이 아니라 ``StudyMemberSubmission/weeks`` 배열로 내려주므로,
/// ``StudyMemberSubmission/managementItems`` 가 주차별로 펼쳐 이 모델을 만듭니다.
///
/// - Note: 서버 제출 현황 응답에는 **주차별 과제명이 없습니다**(주차 번호와
///   `weeklyCurriculumId` 만 옵니다). 그래서 ``title`` 은 주차 번호에서 파생한 표시 문자열이며,
///   서버가 내려준 값이 아닙니다. 서버가 과제명을 추가하면 그 값으로 교체하면 됩니다.
public struct StudyManagementItem: Identifiable, Equatable, Sendable {

    // MARK: - Property

    /// 카드 식별자 — 같은 스터디원의 주차 카드가 서로 구분되도록 멤버 × 주차로 합성합니다.
    public let id: String
    /// 스터디 그룹 멤버 식별자 (서버 응답)
    public let studyGroupMemberId: String
    /// 멤버 식별자 (서버 응답)
    public let memberId: String
    /// 챌린저 워크북 식별자 — `nil` 이면 미배포라 상세로 이동할 수 없습니다.
    public let challengerWorkbookId: String?
    /// 주차 커리큘럼 식별자 (서버 응답)
    public let weeklyCurriculumId: String
    /// 주차 번호 (서버 응답)
    public let weekNo: String
    /// 프로필 이미지 주소
    public let profileImageURL: String?
    /// 표시 이름
    public let name: String
    /// 소속 학교명
    public let school: String
    /// 파트 표시 라벨
    public let part: String
    /// 카드에 표시할 과제 문구 (주차 번호에서 파생)
    public let title: String
    /// 워크북 평가 상태
    public let state: ChallengerWorkbookStatus
    /// 베스트 워크북 여부 — ``state`` 와 독립입니다.
    public let isBest: Bool

    // MARK: - Initializer

    public init(
        id: String,
        studyGroupMemberId: String,
        memberId: String,
        challengerWorkbookId: String? = nil,
        weeklyCurriculumId: String,
        weekNo: String,
        profileImageURL: String? = nil,
        name: String,
        school: String,
        part: String,
        title: String,
        state: ChallengerWorkbookStatus,
        isBest: Bool = false
    ) {
        self.id = id
        self.studyGroupMemberId = studyGroupMemberId
        self.memberId = memberId
        self.challengerWorkbookId = challengerWorkbookId
        self.weeklyCurriculumId = weeklyCurriculumId
        self.weekNo = weekNo
        self.profileImageURL = profileImageURL
        self.name = name
        self.school = school
        self.part = part
        self.title = title
        self.state = state
        self.isBest = isBest
    }

    /// 스터디원 행과 그 주차 하나를 합쳐 카드 행을 만든다.
    ///
    /// - Parameters:
    ///   - submission: 스터디원 행 (이름·학교·파트 등 공통 정보)
    ///   - week: 펼칠 주차
    public init(submission: StudyMemberSubmission, week: WeeklySubmission) {
        self.init(
            id: "\(submission.studyGroupMemberId)-\(week.weeklyCurriculumId)",
            studyGroupMemberId: submission.studyGroupMemberId,
            memberId: submission.memberId,
            challengerWorkbookId: week.challengerWorkbookId,
            weeklyCurriculumId: week.weeklyCurriculumId,
            weekNo: week.weekNo,
            profileImageURL: submission.profileImageURL,
            name: submission.displayName,
            school: submission.schoolName ?? "",
            part: submission.partLabel,
            title: Self.makeTitle(weekNo: week.weekNo),
            state: week.status,
            isBest: week.isBest
        )
    }

    // MARK: - Computed Property

    /// 워크북 상세로 이동할 수 있는지 여부
    ///
    /// 워크북이 배포되지 않은 인원은 상세 대상이 없으므로 진입을 막습니다.
    public var canOpenDetail: Bool {
        challengerWorkbookId != nil
    }

    // MARK: - Function

    /// 주차 번호로부터 카드 문구를 만든다.
    ///
    /// 서버가 과제명을 주지 않아 주차 번호로 대신 표시합니다.
    private static func makeTitle(weekNo: String) -> String {
        weekNo.isEmpty ? "워크북" : "\(weekNo)주차 워크북"
    }
}
