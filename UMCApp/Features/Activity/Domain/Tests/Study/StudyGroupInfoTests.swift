//
//  StudyGroupInfoTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

private func makeMember(
    serverID: String = "m_001",
    name: String = "홍길동",
    nickname: String? = nil,
    role: StudyGroupMember.MemberRole = .member,
    bestWorkbookPoint: Int = 0
) -> StudyGroupMember {
    StudyGroupMember(
        serverID: serverID,
        name: name,
        nickname: nickname,
        university: "한성대",
        role: role,
        bestWorkbookPoint: bestWorkbookPoint
    )
}

private func makeGroup(
    mentors: [StudyGroupMember],
    members: [StudyGroupMember] = [],
    createdDate: Date = Date(timeIntervalSince1970: 1_736_942_400)
) -> StudyGroupInfo {
    StudyGroupInfo(
        serverID: "g_001",
        name: "iOS 스터디",
        part: .front(type: .ios),
        createdDate: createdDate,
        mentors: mentors,
        members: members
    )
}

// MARK: - Suite

@Suite("StudyGroupInfo — 그룹 구성 도메인 규칙")
struct StudyGroupInfoTests {

    // MARK: - memberCount

    @Test("memberCount는 파트장과 챌린저 수의 합과 같다")
    func memberCountSumsMentorsAndMembers() {
        let mentor = makeMember(serverID: "mentor_1", role: .leader)
        let m1 = makeMember(serverID: "m_1")
        let m2 = makeMember(serverID: "m_2")
        let m3 = makeMember(serverID: "m_3")

        let group = makeGroup(mentors: [mentor], members: [m1, m2, m3])

        #expect(group.memberCount == 4)
    }

    @Test("챌린저가 비어있으면 memberCount는 파트장 수와 같다")
    func memberCountWithEmptyMembers() {
        let mentor1 = makeMember(serverID: "mentor_1", role: .leader)
        let mentor2 = makeMember(serverID: "mentor_2", role: .leader)

        let group = makeGroup(mentors: [mentor1, mentor2])

        #expect(group.memberCount == 2)
    }

    // MARK: - primaryMentor

    @Test("primaryMentor는 mentors 배열의 첫 번째 파트장을 반환한다")
    func primaryMentorIsFirstMentor() {
        let lead = makeMember(serverID: "lead", role: .leader)
        let secondary = makeMember(serverID: "second", role: .leader)

        let group = makeGroup(mentors: [lead, secondary])

        #expect(group.primaryMentor?.serverID == "lead")
    }

    @Test("파트장이 없으면 primaryMentor는 nil이다")
    func primaryMentorIsNilWhenNoMentors() {
        let group = makeGroup(mentors: [])

        #expect(group.primaryMentor == nil)
    }

    // MARK: - formattedCreatedDate

    @Test("formattedCreatedDate는 'yyyy.MM.dd' 패턴 문자열을 반환한다")
    func formattedCreatedDateMatchesPattern() {
        let group = makeGroup(mentors: [])

        let pattern = #"^\d{4}\.\d{2}\.\d{2}$"#
        #expect(group.formattedCreatedDate.range(of: pattern, options: .regularExpression) != nil)
    }

    @Test("서로 다른 날짜는 서로 다른 문자열로 포맷된다")
    func formattedCreatedDateDiffersByInput() {
        let day1 = Date(timeIntervalSince1970: 1_736_942_400) // 2025-01-15 12:00 UTC
        let day2 = Date(timeIntervalSince1970: 1_739_534_400) // 2025-02-14 12:00 UTC

        let g1 = makeGroup(mentors: [], createdDate: day1)
        let g2 = makeGroup(mentors: [], createdDate: day2)

        #expect(g1.formattedCreatedDate != g2.formattedCreatedDate)
    }
}
