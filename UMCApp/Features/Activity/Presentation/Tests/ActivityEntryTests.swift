//
//  ActivityEntryTests.swift
//  ActivityPresentationTests
//
//  Created by euijjang97 on 8/29/26.
//

import CoreDomain
import Testing
@testable import ActivityPresentation

@Suite("ActivityEntry — 밖에서 들어온 진입 요청의 섹션 해석")
struct ActivityEntryTests {

    /// 마이페이지 「나의 스터디」가 착지해야 하는 자리. 모드를 잘못 보면 운영진에게
    /// 챌린저 섹션이 잡혀 `ActivityView` 의 모드×섹션 스위치가 빈 화면으로 떨어진다.
    @Test(
        "스터디 요청은 모드별 스터디 섹션으로 해석된다",
        arguments: [
            (ActivityMode.challenger, ActivitySection.studyActivity),
            (ActivityMode.admin, ActivitySection.studyManage),
        ]
    )
    func studyResolvesPerMode(mode: ActivityMode, expected: ActivitySection) {
        #expect(ActivityEntry.study.section(in: mode) == expected)
    }
}
