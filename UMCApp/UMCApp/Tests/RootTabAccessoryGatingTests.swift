//
//  RootTabAccessoryGatingTests.swift
//  UMCAppTests
//
//  Created by euijjang97 on 8/10/26.
//

import CoreRouting
import Testing
import UMCFoundation
@testable import UMCApp

@Suite("RootTabAccessory — 탭바 하단 액세서리 노출 게이팅")
struct RootTabAccessoryGatingTests {

    @Test("루트 화면에서는 액세서리를 노출한다", arguments: [
        NavigationTab.home,
        .community,
        .mypage
    ])
    func showsOnRoot(tab: NavigationTab) {
        #expect(RootTabAccessoryView.shouldShow(
            tab: tab,
            isAtRoot: true,
            role: .challenger,
            canToggleAdminMode: false
        ))
    }

    @Test("스택에 화면이 쌓여 있으면 어떤 탭에서도 노출하지 않는다", arguments: NavigationTab.allCases)
    func hiddenWhenStackIsPushed(tab: NavigationTab) {
        #expect(RootTabAccessoryView.shouldShow(
            tab: tab,
            isAtRoot: false,
            role: .schoolPresident,
            canToggleAdminMode: true
        ) == false)
    }

    @Test("공지 탭은 공지 작성 권한이 없는 역할에서 노출하지 않는다", arguments: [
        ManagementTeam.challenger,
        .centralOperatingTeamMember
    ])
    func hiddenOnNoticeWithoutWritePermission(role: ManagementTeam) {
        #expect(RootTabAccessoryView.shouldShow(
            tab: .notice,
            isAtRoot: true,
            role: role,
            canToggleAdminMode: true
        ) == false)
    }

    @Test("공지 탭은 작성 권한이 있는 역할에서 노출한다")
    func showsOnNoticeWithWritePermission() {
        #expect(RootTabAccessoryView.shouldShow(
            tab: .notice,
            isAtRoot: true,
            role: .schoolPresident,
            canToggleAdminMode: true
        ))
    }

    @Test("활동 탭은 운영진 모드 전환 권한이 있을 때만 노출한다", arguments: [true, false])
    func showsOnActivityOnlyWithAdminPermission(canToggleAdminMode: Bool) {
        #expect(RootTabAccessoryView.shouldShow(
            tab: .activity,
            isAtRoot: true,
            role: .schoolPresident,
            canToggleAdminMode: canToggleAdminMode
        ) == canToggleAdminMode)
    }
}
