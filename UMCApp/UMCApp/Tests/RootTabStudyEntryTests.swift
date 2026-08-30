//
//  RootTabStudyEntryTests.swift
//  UMCAppTests
//
//  Created by euijjang97 on 8/29/26.
//

import ActivityPresentation
import CoreRouting
import SwiftUI
import Testing
@testable import UMCApp

@Suite("RootTab — 마이페이지 「나의 스터디」 진입 전이")
struct RootTabStudyEntryTests {

    /// 탭만 바꾸면 Activity 탭에 남아 있던 스택이 복원돼 이전에 보던 상세에 착지한다.
    /// 스터디 섹션은 탭 **루트**에 있으므로 경로를 비우는 것까지가 이 전이다.
    @Test("Activity 탭 스택을 비우고 그 탭으로 옮긴 뒤 스터디를 요청한다")
    func resetsActivityStackAndRequestsStudy() {
        let pathStore = PathStore()
        pathStore.push("attendanceDetail", on: .activity)
        pathStore.push("studyScheduleRegistration", on: .activity)
        pathStore.push("settings", on: .mypage)
        pathStore.selectedTab = .mypage

        let entry = RootTabView.enterActivityStudy(pathStore: pathStore)

        #expect(entry == .study)
        #expect(pathStore.isAtRoot(.activity))
        #expect(pathStore.selectedTab == .activity)
        // 되돌리는 건 Activity 탭 하나다 — 마이페이지로 돌아오면 있던 자리 그대로여야 한다.
        #expect(pathStore.depth(of: .mypage) == 1)
    }
}
