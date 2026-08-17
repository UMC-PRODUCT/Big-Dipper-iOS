//
//  UMCPartTypeSeedColorTests.swift
//  CoreUIComponentsTests
//
//  Created by One on 8/18/26.
//

import SwiftUI
import Testing
import UIKit
import UMCFoundation
@testable import CoreUIComponents

@Suite("UMCPartType+SeedColor — 명함 파트 시드 컬러")
struct UMCPartTypeSeedColorTests {

    /// 명함첩 카드의 배경 그라데이션·칩 색이 전부 이 한 값에서 파생된다.
    /// 값이 틀어지면 시안과 어긋난 카드가 8종 전부 조용히 나가므로 hex 로 못 박는다.
    private static let designSeeds: [(part: UMCPartType, hex: String)] = [
        (.admin, "6155F5"),
        (.design, "FF2D55"),
        (.pm, "CB30E0"),
        (.front(type: .web), "AC7F5E"),
        (.front(type: .android), "00C0E8"),
        (.front(type: .ios), "FF9500"),
        (.server(type: .spring), "34C759"),
        (.server(type: .node), "FFCC00"),
    ]

    @Test("파트마다 시안이 지정한 시드 컬러를 돌려준다", arguments: designSeeds)
    func seedColorMatchesDesign(seed: (part: UMCPartType, hex: String)) {
        #expect(seed.part.seedColor.srgbHex == seed.hex)
    }

    @Test("여덟 파트의 시드 컬러가 서로 겹치지 않는다")
    func seedColorsAreDistinct() {
        let hexes = Self.designSeeds.map(\.part.seedColor.srgbHex)

        #expect(Set(hexes).count == Self.designSeeds.count)
    }

    /// `allCases` 는 `.admin` 을 빼고 7종만 담는다(운영진은 파트 선택 목록에 안 오른다).
    /// 명함은 운영진 카드도 그려야 하므로 그 7종을 덮되 admin 까지 별도로 확인한다.
    @Test("파트 선택 목록(allCases) 전체가 시드 컬러를 갖는다")
    func allSelectablePartsCovered() {
        let covered = Set(Self.designSeeds.map(\.part))

        #expect(UMCPartType.allCases.allSatisfy { covered.contains($0) })
        #expect(covered.contains(.admin))
    }
}

// MARK: - Test Helper

private extension Color {

    /// sRGB 8bit 표기. 시안 hex 문자열과 직접 맞대려고 테스트에서만 쓴다.
    var srgbHex: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
