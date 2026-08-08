//
//  ActivityAccessoryVisibilityTests.swift
//  UMCAppTests
//
//  Created by jaewon Lee on 8/9/26.
//

import Testing

import CoreRouting

@testable import UMCApp

// MARK: - Fixture

/// 게이팅 규칙 입력 3종 + 기대 결과 1개를 묶은 파라미터화 케이스.
private struct VisibilityCase: Sendable, CustomStringConvertible {
    let name: String
    let selectedTab: NavigationTab
    let isActivityTabAtRoot: Bool
    let canToggleAdminMode: Bool
    let expected: Bool

    var description: String { name }
}

private let visibilityCases: [VisibilityCase] = [
    VisibilityCase(
        name: "다른 탭이 선택되어 있으면 나머지 조건과 무관하게 숨긴다",
        selectedTab: .home,
        isActivityTabAtRoot: true,
        canToggleAdminMode: true,
        expected: false
    ),
    VisibilityCase(
        name: "Activity 탭이지만 NavigationStack에 화면이 쌓여 있으면 숨긴다",
        selectedTab: .activity,
        isActivityTabAtRoot: false,
        canToggleAdminMode: true,
        expected: false
    ),
    VisibilityCase(
        name: "Activity 탭 루트여도 운영진 모드 전환 권한이 없으면 숨긴다",
        selectedTab: .activity,
        isActivityTabAtRoot: true,
        canToggleAdminMode: false,
        expected: false
    ),
    VisibilityCase(
        name: "Activity 탭 루트이고 운영진 모드 전환 권한이 있으면 보인다",
        selectedTab: .activity,
        isActivityTabAtRoot: true,
        canToggleAdminMode: true,
        expected: true
    )
]

// MARK: - Tests

@Suite("ActivityAccessoryVisibility — 탭바 액세서리 노출 게이팅 (도메인 규칙)")
struct ActivityAccessoryVisibilityTests {

    @Test("탭 선택·루트 여부·권한 조합에 따라 액세서리 노출을 결정한다", arguments: visibilityCases)
    private func matchesExpectedVisibility(_ testCase: VisibilityCase) {
        let result = ActivityAccessoryVisibility.isVisible(
            selectedTab: testCase.selectedTab,
            isActivityTabAtRoot: testCase.isActivityTabAtRoot,
            canToggleAdminMode: testCase.canToggleAdminMode
        )

        #expect(result == testCase.expected)
    }
}
