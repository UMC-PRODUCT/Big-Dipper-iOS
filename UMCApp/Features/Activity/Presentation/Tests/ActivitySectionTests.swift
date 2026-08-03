//
//  ActivitySectionTests.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDomain
import Testing
@testable import ActivityPresentation

@Suite("ActivitySection — 모드×섹션 분기 (도메인 규칙)")
struct ActivitySectionTests {

    // MARK: - sections(for:)

    @Test(
        "모드별 섹션 목록은 그 모드 전용 3개로 고정된다",
        arguments: [
            (ActivityMode.challenger, [
                ActivitySection.attendanceCheck, .studyActivity, .members,
            ]),
            (ActivityMode.admin, [
                ActivitySection.attendanceManage, .studyManage, .memberManage,
            ]),
        ]
    )
    func sectionsPerMode(mode: ActivityMode, expected: [ActivitySection]) {
        #expect(ActivitySection.sections(for: mode) == expected)
    }

    @Test("두 모드의 섹션은 겹치지 않고 합치면 전체 case 가 된다")
    func sectionsPartitionAllCases() {
        let challenger = Set(ActivitySection.sections(for: .challenger))
        let admin = Set(ActivitySection.sections(for: .admin))

        #expect(challenger.isDisjoint(with: admin))
        #expect(challenger.union(admin) == Set(ActivitySection.allCases))
    }

    // MARK: - defaultSection(for:)

    @Test(
        "모드별 기본 섹션은 출석 계열이다",
        arguments: [
            (ActivityMode.challenger, ActivitySection.attendanceCheck),
            (ActivityMode.admin, ActivitySection.attendanceManage),
        ]
    )
    func defaultSectionPerMode(mode: ActivityMode, expected: ActivitySection) {
        #expect(ActivitySection.defaultSection(for: mode) == expected)
    }

    @Test("기본 섹션은 항상 그 모드 섹션 목록의 첫 항목이다", arguments: ActivityMode.allCases)
    func defaultSectionIsFirstAvailable(mode: ActivityMode) {
        let first = ActivitySection.sections(for: mode)[0]
        #expect(ActivitySection.defaultSection(for: mode) == first)
    }

    // MARK: - mapped(to:)

    @Test(
        "모드를 바꿔도 같은 성격의 자리를 유지한다",
        arguments: [
            (ActivitySection.attendanceCheck, ActivityMode.admin, .attendanceManage),
            (ActivitySection.studyActivity, .admin, .studyManage),
            (ActivitySection.members, .admin, .memberManage),
            (ActivitySection.attendanceManage, .challenger, .attendanceCheck),
            (ActivitySection.studyManage, .challenger, .studyActivity),
            (ActivitySection.memberManage, .challenger, .members),
        ]
    )
    func mappedKeepsCounterpart(
        section: ActivitySection,
        mode: ActivityMode,
        expected: ActivitySection
    ) {
        #expect(section.mapped(to: mode) == expected)
    }

    @Test("이미 그 모드에 속한 섹션은 자기 자신으로 매핑된다", arguments: ActivityMode.allCases)
    func mappedIsIdentityWithinSameMode(mode: ActivityMode) {
        for section in ActivitySection.sections(for: mode) {
            #expect(section.mapped(to: mode) == section)
        }
    }

    @Test("어떤 섹션을 매핑해도 결과는 대상 모드의 섹션 목록 안에 있다")
    func mappedStaysWithinTargetMode() {
        for mode in ActivityMode.allCases {
            let available = Set(ActivitySection.sections(for: mode))
            for section in ActivitySection.allCases {
                #expect(available.contains(section.mapped(to: mode)))
            }
        }
    }

    @Test("모드를 두 번 거쳐도 최종 모드로 직접 매핑한 것과 같다")
    func mappedIsPathIndependent() {
        for section in ActivitySection.allCases {
            for first in ActivityMode.allCases {
                for second in ActivityMode.allCases {
                    #expect(
                        section.mapped(to: first).mapped(to: second) == section.mapped(to: second)
                    )
                }
            }
        }
    }
}
