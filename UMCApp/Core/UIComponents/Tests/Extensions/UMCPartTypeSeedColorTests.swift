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

    /// 회색과 유채색을 가르는 채널폭 경계. 실측은 폴백 13(라이트)·22(다크) 대 시드 최소
    /// 78(Web) 이라 그 사이 어디를 잡아도 되고, 양쪽에 넉넉한 40 으로 둔다.
    private static let greyChannelSpreadLimit = 40

    /// WCAG AA 본문 기준.
    private static let minimumContrastRatio = 4.5

    @Test("파트마다 시안이 지정한 시드 컬러를 돌려준다", arguments: designSeeds)
    func seedColorMatchesDesign(seed: (part: UMCPartType, hex: String)) {
        #expect(seed.part.seedColor.srgbHex == seed.hex)
    }

    @Test("여덟 파트의 시드 컬러가 서로 겹치지 않는다")
    func seedColorsAreDistinct() {
        let hexes = Self.designSeeds.map(\.part.seedColor.srgbHex)

        #expect(Set(hexes).count == Self.designSeeds.count)
    }

    /// 못 읽은 파트는 `.admin` 으로 떨어져 Admin 인디고를 입던 자리다 (#1236). hex 완전
    /// 일치만 보면 폴백을 `6155F6`(Admin 에서 1비트) 로 옮겨도 통과하면서 「운영진처럼
    /// 보임」이 되살아나므로, **회색이라는 성질 자체**를 채널폭으로 못 박는다.
    @Test("미정의 파트 폴백은 저채도 회색이라 유채색 시드와 섞이지 않는다")
    func unresolvedSeedIsLowChromaGrey() {
        let fallback = UMCPartType.unresolvedSeedColor
        let hexes = Set(Self.designSeeds.map(\.part.seedColor.srgbHex))

        #expect(!hexes.contains(fallback.srgbHex))
        #expect(
            fallback.channelSpread < Self.greyChannelSpreadLimit,
            "폴백 채널폭 \(fallback.channelSpread)"
        )

        for seed in Self.designSeeds {
            #expect(
                seed.part.seedColor.channelSpread > Self.greyChannelSpreadLimit,
                "\(seed.part.name) 채널폭 \(seed.part.seedColor.channelSpread)"
            )
        }
    }

    /// 이 값이 흰 라벨(#1235, 8종 전부 미달)을 버리고 검정 라벨로 간 근거다. 시드나
    /// 혼합비를 건드리면 화면이 아니라 여기서 먼저 깨져야 한다.
    @Test(
        "파트 칩 면 위 검정 라벨이 여덟 파트 전부 WCAG AA(4.5:1)를 넘는다",
        arguments: designSeeds
    )
    func chipSeedColorPassesBlackLabelContrast(seed: (part: UMCPartType, hex: String)) {
        let ratio = seed.part.chipSeedColor.blackContrastRatio

        #expect(ratio >= Self.minimumContrastRatio, "\(seed.part.name) 대비 \(ratio)")
    }

    /// 폴백만 다이내믹 토큰이라 모드에 따라 변한다 — 어느 모드로 해석되든 기준을 넘는다.
    @Test("못 읽은 파트 폴백 칩 면 위 검정 라벨도 같은 기준을 넘는다")
    func unresolvedChipSeedColorPassesBlackLabelContrast() {
        let ratio = UMCPartType.unresolvedChipSeedColor.blackContrastRatio

        #expect(ratio >= Self.minimumContrastRatio, "폴백 대비 \(ratio)")
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

    /// sRGB 8bit 채널. hex 비교·채널폭·대비 계산이 모두 이 한 값에서 나온다.
    var srgbChannels: (red: Int, green: Int, blue: Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    /// sRGB 8bit 표기. 시안 hex 문자열과 직접 맞대려고 테스트에서만 쓴다.
    var srgbHex: String {
        let channels = srgbChannels
        return String(format: "%02X%02X%02X", channels.red, channels.green, channels.blue)
    }

    /// 최대 채널과 최소 채널의 차. 무채색에 가까울수록 0 에 붙는다.
    var channelSpread: Int {
        let channels = [srgbChannels.red, srgbChannels.green, srgbChannels.blue]
        return (channels.max() ?? 0) - (channels.min() ?? 0)
    }

    /// WCAG 2.1 상대 휘도.
    var relativeLuminance: Double {
        let channels = srgbChannels
        func linear(_ value: Int) -> Double {
            let normalized = Double(value) / 255
            return normalized <= 0.03928
                ? normalized / 12.92
                : pow((normalized + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(channels.red)
            + 0.7152 * linear(channels.green)
            + 0.0722 * linear(channels.blue)
    }

    /// 검정 잉크와의 대비비 — 검정 휘도가 0 이라 `(L + 0.05) / 0.05` 로 줄어든다.
    var blackContrastRatio: Double {
        (relativeLuminance + 0.05) / 0.05
    }
}
