//
//  CurriculumProgressModelTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

// MARK: - Helpers

private func makeProgress(
    completed: Int,
    total: Int,
    partType: UMCPartType? = .front(type: .ios)
) -> CurriculumProgressModel {
    CurriculumProgressModel(
        partType: partType,
        partName: "iOS PART CURRICULUM",
        curriculumTitle: "iOS 커리큘럼",
        completedCount: completed,
        totalCount: total
    )
}

// MARK: - Suite

@Suite("CurriculumProgressModel — 진행률 계산 (도메인 규칙)")
struct CurriculumProgressModelTests {

    // MARK: - progress

    @Test("totalCount 가 0이면 progress 는 0을 반환한다 (분모 0 안전)")
    func progressIsZeroWhenTotalIsZero() {
        let model = makeProgress(completed: 0, total: 0)

        #expect(model.progress == 0)
    }

    @Test(
        "progress 는 completedCount / totalCount 비율을 그대로 반환한다",
        arguments: [
            (0, 8, 0.0),
            (4, 8, 0.5),
            (8, 8, 1.0),
            (1, 3, 1.0 / 3.0)
        ]
    )
    func progressRatio(completed: Int, total: Int, expected: Double) {
        let model = makeProgress(completed: completed, total: total)

        #expect(abs(model.progress - expected) < 0.0001)
    }

    // MARK: - progressPercentage

    @Test(
        "progressPercentage 는 progress * 100 을 정수 절단(truncation) 한다",
        arguments: [
            (0, 8, 0),
            (4, 8, 50),
            (1, 3, 33),
            (8, 8, 100)
        ]
    )
    func progressPercentageTruncation(completed: Int, total: Int, expected: Int) {
        let model = makeProgress(completed: completed, total: total)

        #expect(model.progressPercentage == expected)
    }

    // MARK: - completionText

    @Test("completionText 포맷은 '{완료}/{전체} 완료' 이다")
    func completionTextFormat() {
        let model = makeProgress(completed: 2, total: 8)

        #expect(model.completionText == "2/8 완료")
    }

    @Test("completionText 는 0/0 같은 경계값도 그대로 노출한다")
    func completionTextZeroBoundary() {
        let model = makeProgress(completed: 0, total: 0)

        #expect(model.completionText == "0/0 완료")
    }
}
