//
//  MissionStatusTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("MissionStatus — hasBorder 분기 (도메인 규칙)")
struct MissionStatusTests {

    @Test(
        "hasBorder 는 .inProgress 일 때만 true 를 반환한다",
        arguments: [
            (MissionStatus.notStarted, false),
            (MissionStatus.inProgress, true),
            (MissionStatus.pendingApproval, false),
            (MissionStatus.pass, false),
            (MissionStatus.fail, false),
            (MissionStatus.completed, false),
            (MissionStatus.locked, false)
        ]
    )
    func hasBorderOnlyForInProgress(status: MissionStatus, expected: Bool) {
        #expect(status.hasBorder == expected)
    }
}
