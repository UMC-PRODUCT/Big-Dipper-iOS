//
//  ManagementTeamTests.swift
//  UMCFoundationTests
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation
import Testing
@testable import UMCFoundation

@Suite("ManagementTeam — 역할 권한 계층 (도메인 규칙)")
struct ManagementTeamTests {

    // MARK: - rawValue Mapping

    @Test(
        "서버 roleType rawValue ↔ enum 매핑이 정확하다",
        arguments: [
            ("SUPER_ADMIN", ManagementTeam.superAdmin),
            ("CENTRAL_PRESIDENT", .centralPresident),
            ("SCHOOL_PART_LEADER", .schoolPartLeader),
            ("CHALLENGER", .challenger)
        ]
    )
    func rawValueMapping(raw: String, expected: ManagementTeam) {
        #expect(ManagementTeam(rawValue: raw) == expected)
        #expect(expected.rawValue == raw)
    }

    // MARK: - level

    @Test("superAdmin 이 전체에서 가장 높은 레벨이다")
    func superAdminHasHighestLevel() {
        let maxLevel = ManagementTeam.allCases.map(\.level).max()

        #expect(ManagementTeam.superAdmin.level == maxLevel)
    }

    @Test("challenger 의 레벨은 0 이다")
    func challengerLevelIsZero() {
        #expect(ManagementTeam.challenger.level == 0)
    }

    // MARK: - Comparable

    @Test(
        "역할 쌍의 대소 비교가 레벨 순서를 따른다",
        arguments: [
            (ManagementTeam.challenger, ManagementTeam.schoolPartLeader),
            (.schoolEtcAdmin, .schoolPresident),
            (.chapterPresident, .centralPresident)
        ]
    )
    func lowerLevelComparesLessThanHigher(lower: ManagementTeam, higher: ManagementTeam) {
        #expect(lower < higher)
    }

    // MARK: - highestPriority(in:)

    @Test("highestPriority 는 가장 상위 권한을 반환한다")
    func highestPriorityReturnsMaxRole() {
        let roles: [ManagementTeam] = [.challenger, .schoolPartLeader, .centralVicePresident]

        #expect(ManagementTeam.highestPriority(in: roles) == .centralVicePresident)
    }

    @Test("빈 역할 목록의 highestPriority 는 nil 이다")
    func highestPriorityOfEmptyIsNil() {
        #expect(ManagementTeam.highestPriority(in: [ManagementTeam]()) == nil)
    }

    // MARK: - displayName / icon

    @Test("challenger 는 아이콘이 없어 displayName 이 한글명과 같다")
    func challengerDisplayNameEqualsKorean() {
        #expect(ManagementTeam.challenger.icon.isEmpty)
        #expect(ManagementTeam.challenger.displayName == ManagementTeam.challenger.korean)
    }

    @Test("아이콘이 있는 역할은 displayName 에 아이콘이 접두된다")
    func iconedRoleDisplayNameHasIconPrefix() {
        let role = ManagementTeam.superAdmin

        #expect(role.icon.isEmpty == false)
        #expect(role.displayName == "\(role.icon) \(role.korean)")
    }

    // MARK: - Korean

    @Test(
        "한글 표시명 매핑이 정확하다",
        arguments: [
            (ManagementTeam.centralPresident, "총괄"),
            (.schoolPresident, "교내 회장"),
            (.challenger, "챌린저")
        ]
    )
    func koreanMapping(role: ManagementTeam, expected: String) {
        #expect(role.korean == expected)
    }
}
