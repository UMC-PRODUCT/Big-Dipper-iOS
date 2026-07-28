//
//  FlowLayoutTests.swift
//  CoreUIComponentsTests
//
//  Created by jaewon Lee on 7/28/26.
//

import Foundation
import Testing
@testable import CoreUIComponents

@Suite("FlowLayout — wrapLayout 줄바꿈 계산")
struct FlowLayoutTests {

    // MARK: - Single Row

    @Test("한 줄에 다 들어가면 가로로만 배치된다")
    func fitsInSingleRow() {
        let sizes = [CGSize(width: 40, height: 20), CGSize(width: 40, height: 20)]

        let result = FlowLayout.wrapLayout(sizes: sizes, maxWidth: 200, spacing: 10)

        #expect(result.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0)])
        #expect(result.totalSize == CGSize(width: 200, height: 20))
    }

    @Test("빈 배열이면 원점도 높이도 0이다")
    func emptySizesProducesZeroHeight() {
        let result = FlowLayout.wrapLayout(sizes: [], maxWidth: 200, spacing: 10)

        #expect(result.origins.isEmpty)
        #expect(result.totalSize == CGSize(width: 200, height: 0))
    }

    // MARK: - Wrapping

    @Test("폭을 넘는 항목은 다음 줄로 줄바꿈된다")
    func wrapsToNextRowWhenExceedingMaxWidth() {
        let sizes = [
            CGSize(width: 80, height: 20),
            CGSize(width: 80, height: 20),
            CGSize(width: 80, height: 20),
        ]

        let result = FlowLayout.wrapLayout(sizes: sizes, maxWidth: 100, spacing: 10)

        #expect(result.origins == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 30),
            CGPoint(x: 0, y: 60),
        ])
        #expect(result.totalSize == CGSize(width: 100, height: 80))
    }

    @Test("줄 높이는 해당 줄에서 가장 큰 항목 기준으로 계산된다")
    func rowHeightUsesTallestItemInRow() {
        let sizes = [
            CGSize(width: 30, height: 20),
            CGSize(width: 30, height: 40),
            CGSize(width: 90, height: 15),
        ]

        let result = FlowLayout.wrapLayout(sizes: sizes, maxWidth: 100, spacing: 10)

        #expect(result.origins == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 40, y: 0),
            CGPoint(x: 0, y: 50),
        ])
        #expect(result.totalSize == CGSize(width: 100, height: 65))
    }

    // MARK: - Spacing

    @Test(
        "spacing 값에 따라 항목 사이 간격이 달라진다",
        arguments: [CGFloat(0), CGFloat(4), CGFloat(16)]
    )
    func spacingAffectsOriginGap(spacing: CGFloat) {
        let sizes = [CGSize(width: 30, height: 10), CGSize(width: 30, height: 10)]

        let result = FlowLayout.wrapLayout(sizes: sizes, maxWidth: 200, spacing: spacing)

        #expect(result.origins[1].x == 30 + spacing)
    }

    // MARK: - Exact Boundary

    @Test("폭에 정확히 맞아떨어지면 줄바꿈되지 않는다")
    func exactWidthFitDoesNotWrap() {
        let sizes = [CGSize(width: 60, height: 20), CGSize(width: 30, height: 20)]

        let result = FlowLayout.wrapLayout(sizes: sizes, maxWidth: 100, spacing: 10)

        #expect(result.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 70, y: 0)])
        #expect(result.totalSize == CGSize(width: 100, height: 20))
    }
}
