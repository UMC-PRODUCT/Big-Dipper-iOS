//
//  AdminModeToggleGatingTests.swift
//  UMCAppTests
//
//  Created by euijjang97 on 8/10/26.
//

import CoreRouting
import Testing
@testable import UMCApp

@Suite("AdminModeToggle — 탭바 하단 액세서리 노출 게이팅")
struct AdminModeToggleGatingTests {

    @Test("Activity 탭 루트에서 운영진 권한이 있으면 노출한다")
    func showsOnActivityRootWithPermission() {
        #expect(AdminModeToggle.shouldShow(
            selectedTab: .activity,
            isAtRoot: true,
            canToggleAdminMode: true
        ))
    }

    @Test("운영진 권한이 없으면 노출하지 않는다")
    func hiddenWithoutAdminPermission() {
        #expect(AdminModeToggle.shouldShow(
            selectedTab: .activity,
            isAtRoot: true,
            canToggleAdminMode: false
        ) == false)
    }

    @Test("Activity 스택에 화면이 쌓여 있으면 노출하지 않는다")
    func hiddenWhenActivityStackIsPushed() {
        #expect(AdminModeToggle.shouldShow(
            selectedTab: .activity,
            isAtRoot: false,
            canToggleAdminMode: true
        ) == false)
    }

    @Test("Activity 가 아닌 탭에서는 조건이 모두 충족돼도 노출하지 않는다", arguments: [
        NavigationTab.home,
        .notice,
        .community,
        .mypage
    ])
    func hiddenOnOtherTabs(tab: NavigationTab) {
        #expect(AdminModeToggle.shouldShow(
            selectedTab: tab,
            isAtRoot: true,
            canToggleAdminMode: true
        ) == false)
    }
}
