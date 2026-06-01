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

    @Test(
        "status 는 var 로 선언되어 자유 전이를 허용한다",
        arguments: [
            (MissionStatus.notStarted, MissionStatus.inProgress),
            (MissionStatus.inProgress, MissionStatus.completed),
            (MissionStatus.notStarted, MissionStatus.completed)
        ]
    )
    func statusCanMutate(initial: MissionStatus, target: MissionStatus) {
        // Given
        var card = makeCard(status: initial)

        // When
        card.status = target

        // Then
        #expect(card.status == target)
    }

    // MARK: - isExtra default

    @Test("isExtra 의 기본값은 false 이다")
    func isExtraDefaultsToFalse() {
        // Given
        let card = makeCard()

        // When
        let isExtra = card.isExtra

        // Then
        #expect(isExtra == false)
    }

    @Test("isExtra=true 로 지정하면 그 값이 그대로 노출된다")
    func isExtraReflectsInput() {
        // Given
        let card = makeCard(isExtra: true)

        // When
        let isExtra = card.isExtra

        // Then
        #expect(isExtra == true)
    }

    // MARK: - missionType default

    @Test("missionType 의 기본값은 .link 이다")
    func missionTypeDefaultsToLink() {
        // Given
        let card = MissionCardModel(
            week: 1,
            platform: "iOS",
            title: "Week 1",
            missionTitle: "워크북",
            status: .notStarted
        )

        // When
        let type = card.missionType

        // Then
        #expect(type == .link)
    }
}
