//
//  MissionCardModelTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

private func makeCard(
    week: Int = 1,
    missionType: MissionType = .link,
    status: MissionStatus = .notStarted,
    isExtra: Bool = false
) -> MissionCardModel {
    MissionCardModel(
        week: week,
        platform: "iOS",
        title: "Week \(week)",
        missionTitle: "워크북 작성",
        missionType: missionType,
        status: status,
        isExtra: isExtra
    )
}

// MARK: - Suite

@Suite("MissionCardModel — 상태/속성 도메인 규칙")
struct MissionCardModelTests {

    // MARK: - status mutability

    @Test("status 는 var 로 선언되어 inProgress → completed 같은 전이를 허용한다")
    func statusCanMutate() {
        var card = makeCard(status: .notStarted)

        card.status = .inProgress
        #expect(card.status == .inProgress)

        card.status = .completed
        #expect(card.status == .completed)
    }

    // MARK: - isExtra default

    @Test("isExtra 의 기본값은 false 이다")
    func isExtraDefaultsToFalse() {
        let card = makeCard()

        #expect(card.isExtra == false)
    }

    @Test("isExtra=true 로 지정하면 그 값이 그대로 노출된다")
    func isExtraReflectsInput() {
        let card = makeCard(isExtra: true)

        #expect(card.isExtra == true)
    }

    // MARK: - missionType default

    @Test("missionType 의 기본값은 .link 이다")
    func missionTypeDefaultsToLink() {
        let card = MissionCardModel(
            week: 1,
            platform: "iOS",
            title: "Week 1",
            missionTitle: "워크북",
            status: .notStarted
        )

        #expect(card.missionType == .link)
    }
}
