//
//  StudyManagementItemTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

private func makeWeek(
    weekNo: String = "1",
    weeklyCurriculumId: String = "WC-1",
    challengerWorkbookId: String? = "CW-1",
    status: ChallengerWorkbookStatus = .pass,
    isBest: Bool = false
) -> WeeklySubmission {
    WeeklySubmission(
        weekNo: weekNo,
        weeklyCurriculumId: weeklyCurriculumId,
        challengerWorkbookId: challengerWorkbookId,
        status: status,
        isBest: isBest
    )
}

/// - Parameters:
///   - nickname: 이름 폴백 경로 검증용 — `nil`/공백이면 실명이 표시된다.
///   - schoolName: 학교 미제공 경로 검증용 — `nil` 이면 빈 문자열로 매핑된다.
private func makeSubmission(
    memberName: String = "박철수",
    nickname: String? = "철수",
    schoolName: String? = "한성대학교",
    profileImageURL: String? = nil,
    partLabel: String = "iOS",
    weeks: [WeeklySubmission] = [makeWeek()]
) -> StudyMemberSubmission {
    StudyMemberSubmission(
        studyGroupMemberId: "SGM-1",
        memberId: "M-1",
        memberName: memberName,
        nickname: nickname,
        schoolName: schoolName,
        profileImageURL: profileImageURL,
        studyGroupId: "G-1",
        studyGroupName: "iOS 스터디 A팀",
        part: .front(type: .ios),
        partLabel: partLabel,
        weeks: weeks
    )
}

// MARK: - 상세 진입 가능 여부

@Suite("StudyManagementItem — 제출 현황 카드 매핑 (도메인 규칙)")
struct StudyManagementItemTests {

    @Test(
        "워크북이 배포된 주차만 상세로 이동할 수 있다",
        arguments: [
            ("CW-1", true),
            (String?.none, false)
        ]
    )
    func canOpenDetailFollowsWorkbookPresence(
        challengerWorkbookId: String?,
        expected: Bool
    ) {
        let week = makeWeek(
            challengerWorkbookId: challengerWorkbookId,
            status: challengerWorkbookId == nil ? .notSubmitted : .pass
        )

        let item = StudyManagementItem(submission: makeSubmission(), week: week)

        #expect(item.canOpenDetail == expected)
    }

    @Test("미배포 인원 주차는 상태가 .notSubmitted 로 그대로 전달된다")
    func notSubmittedStateIsPreserved() {
        let week = makeWeek(challengerWorkbookId: nil, status: .notSubmitted)

        let item = StudyManagementItem(submission: makeSubmission(), week: week)

        #expect(item.state == .notSubmitted)
        #expect(item.challengerWorkbookId == nil)
    }

    // MARK: - 식별자 합성

    @Test("카드 id 는 멤버 × 주차로 합성돼 같은 스터디원의 주차 카드가 구분된다")
    func idCombinesMemberAndWeek() {
        let submission = makeSubmission(
            weeks: [
                makeWeek(weekNo: "1", weeklyCurriculumId: "WC-1"),
                makeWeek(weekNo: "2", weeklyCurriculumId: "WC-2")
            ]
        )

        let ids = submission.managementItems.map(\.id)

        #expect(ids == ["SGM-1-WC-1", "SGM-1-WC-2"])
    }

    // MARK: - 표시 값 매핑

    @Test(
        "이름은 닉네임 우선, 닉네임이 없거나 공백뿐이면 실명으로 폴백한다",
        arguments: [
            ("철수", "철수"),
            (String?.none, "박철수"),
            ("   ", "박철수")
        ]
    )
    func nameFallsBackToMemberName(nickname: String?, expected: String) {
        let submission = makeSubmission(nickname: nickname)

        let item = StudyManagementItem(submission: submission, week: makeWeek())

        #expect(item.name == expected)
    }

    @Test("학교가 없으면 빈 문자열로 매핑된다")
    func schoolMapsToEmptyStringWhenMissing() {
        let submission = makeSubmission(schoolName: nil)

        let item = StudyManagementItem(submission: submission, week: makeWeek())

        #expect(item.school.isEmpty)
    }

    @Test(
        "서버가 과제명을 주지 않으므로 title 은 주차 번호에서 파생된다",
        arguments: [
            ("1", "1주차 워크북"),
            ("12", "12주차 워크북"),
            ("", "워크북")
        ]
    )
    func titleDerivesFromWeekNo(weekNo: String, expected: String) {
        let week = makeWeek(weekNo: weekNo)

        let item = StudyManagementItem(submission: makeSubmission(), week: week)

        #expect(item.title == expected)
    }

    @Test("베스트 여부는 상태와 독립적으로 전달된다 (통과이면서 베스트 가능)")
    func isBestIsIndependentOfStatus() {
        let week = makeWeek(status: .pass, isBest: true)

        let item = StudyManagementItem(submission: makeSubmission(), week: week)

        #expect(item.state == .pass)
        #expect(item.isBest)
    }
}

// MARK: - 주차 펼치기

@Suite("StudyMemberSubmission — 주차 펼치기 (도메인 규칙)")
struct StudyMemberSubmissionTests {

    @Test("주차 배열을 카드 행으로 펼치면 행 수가 주차 수와 같다")
    func managementItemsCountMatchesWeeks() {
        let submission = makeSubmission(
            weeks: [
                makeWeek(weekNo: "1", weeklyCurriculumId: "WC-1"),
                makeWeek(weekNo: "2", weeklyCurriculumId: "WC-2"),
                makeWeek(weekNo: "3", weeklyCurriculumId: "WC-3")
            ]
        )

        #expect(submission.managementItems.count == 3)
    }

    @Test("주차는 번호 오름차순으로 정렬된다 (10주차가 2주차보다 뒤)")
    func managementItemsSortNumerically() {
        let submission = makeSubmission(
            weeks: [
                makeWeek(weekNo: "10", weeklyCurriculumId: "WC-10"),
                makeWeek(weekNo: "2", weeklyCurriculumId: "WC-2"),
                makeWeek(weekNo: "1", weeklyCurriculumId: "WC-1")
            ]
        )

        let weekNos = submission.managementItems.map(\.weekNo)

        #expect(weekNos == ["1", "2", "10"])
    }

    @Test("숫자로 읽히지 않는 주차는 뒤로 밀린다")
    func nonNumericWeekSortsLast() {
        let submission = makeSubmission(
            weeks: [
                makeWeek(weekNo: "보충", weeklyCurriculumId: "WC-X"),
                makeWeek(weekNo: "1", weeklyCurriculumId: "WC-1")
            ]
        )

        let weekNos = submission.managementItems.map(\.weekNo)

        #expect(weekNos == ["1", "보충"])
    }

    @Test("주차가 비어 있으면 카드 행도 비어 있다")
    func emptyWeeksProduceNoItems() {
        let submission = makeSubmission(weeks: [])

        #expect(submission.managementItems.isEmpty)
    }
}
