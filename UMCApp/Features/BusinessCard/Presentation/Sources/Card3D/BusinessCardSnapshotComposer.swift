//
//  BusinessCardSnapshotComposer.swift
//  BusinessCardPresentation
//
//  Created by One on 8/30/26.
//

import BusinessCardDomain
import CoreGraphics
import CoreUIComponents
import RealityKit
import SwiftUI
import UIKit
import UMCFoundation

/// 스냅샷용 최소 카드 합성기 — **#1248 머지와 함께 이 파일을 통째로 지운다.**
///
/// `BusinessCardComposer`(#1248)와 USDZ 템플릿(#1246)이 아직 develop 에 없어서, 스파이크(#1245)가
/// 검증한 프리미티브 조립(`generateBox` 몸통 + 텍스트 메시 3줄)을 그대로 제품 경로로 올린 것이다.
/// 그리드가 지금 당장 자립해서 동작하기 위한 자리이지 최종 시각 품질이 아니다 — 라운드 코너·재질·
/// 조명·레이아웃은 전부 #1248 소관이다.
///
/// 교체 지점은 ``BusinessCardSnapshotRenderer/defaultComposing`` 한 곳뿐이다.
@MainActor
enum BusinessCardSnapshotComposer {

    // MARK: - Property

    /// 실물 명함 90×50mm 를 1:1 미터로 옮긴 치수. RealityKit 좌표계는 미터다.
    private enum CardGeometry {
        static let width: Float = 0.09
        static let height: Float = 0.05
        static let depth: Float = 0.0006
        static let cornerRadius: Float = 0.003
        /// 텍스트가 카드 면에 파묻히지 않게 띄우는 간격.
        static let surfaceOffset: Float = 0.0002
        static let textInset: Float = 0.006
        static let firstLineTop: Float = 0.012
        static let lineSpacing: Float = 0.009
    }

    private enum Typography {
        /// 실물 명함 이름 줄 크기(6mm). 스파이크 축 2 가 이 크기에서 한글 글리프가 무너지지
        /// 않는 것을 확인했다.
        static let nameSize: CGFloat = 0.006
        /// 이름 아래 두 줄은 보조 정보라 한 단계 작게 둔다.
        static let subordinateRatio: CGFloat = 0.7
        static let extrusionRatio: Float = 0.05
    }

    private enum Portrait {
        /// 카드 세로의 절반을 차지하는 원형 사진. 실제 위치·크기는 #1248 템플릿이 정한다.
        static let sideRatio: Float = 0.5
        static let trailingInset: Float = 0.006
    }

    // MARK: - Function

    /// 프로필을 카드 엔티티로 조립한다.
    ///
    /// - Parameters:
    ///   - card: 앞면에 찍을 프로필. 이름·파트·기수 세 줄이 텍스트 메시가 된다.
    ///   - portrait: 프로필 사진. `nil` 이면 사진 면을 생략한다 — develop 단계에서는 항상 `nil`
    ///     이다(원격 이미지 로더가 #1248 과 함께 들어온다).
    static func compose(_ card: MyCard, portrait: CGImage?) async throws -> Entity {
        let body = ModelEntity(
            mesh: .generateBox(
                width: CardGeometry.width,
                height: CardGeometry.height,
                depth: CardGeometry.depth,
                cornerRadius: CardGeometry.cornerRadius
            ),
            materials: [UnlitMaterial(color: UIColor(card.part.seedColor))]
        )
        body.name = "CardBody"

        let lines = [card.name, card.partDisplayName, "\(card.generation)기"]
        for (index, line) in lines.enumerated() {
            body.addChild(label(line, at: index))
        }

        if let portrait {
            body.addChild(try portraitPlane(portrait))
        }
        return body
    }

    // MARK: - Private

    /// 카드 몸체가 시드 컬러 **불투명 면**이라 그 위의 라벨 색이 곧 대비비다.
    ///
    /// 같은 조합의 실측이 ``ReceivedCardCell`` 칩 주석에 이미 있다 — 시드 + 흰 라벨은 8개 파트
    /// 전부 WCAG AA(4.5:1) 미달(최악 Node 1.42), **검정 라벨은 5.60~14.77 로 8종 전부 통과**.
    /// 몸체 알파는 여기서 건드리지 않는다 — 카드 면의 재질·조명은 #1248 템플릿이 정한다.
    private static func label(_ line: String, at index: Int) -> ModelEntity {
        let size = index == .zero
            ? Typography.nameSize
            : Typography.nameSize * Typography.subordinateRatio
        let entity = ModelEntity(
            mesh: textMesh(line, fontSize: size),
            materials: [UnlitMaterial(color: .black)]
        )
        entity.name = "Text_\(["name", "part", "generation"][index])"
        entity.position = [
            -CardGeometry.width / 2 + CardGeometry.textInset,
            CardGeometry.height / 2 - CardGeometry.firstLineTop
                - Float(index) * CardGeometry.lineSpacing,
            CardGeometry.depth / 2 + CardGeometry.surfaceOffset,
        ]
        return entity
    }

    /// 한글은 CoreText 가 조합형을 알아서 정규화한다 — 스파이크 축 2 에서 NFC/NFD 바운즈 비가
    /// 1.000 이었으므로 합성 전 NFC 정규화를 넣지 않는다.
    private static func textMesh(_ string: String, fontSize: CGFloat) -> MeshResource {
        .generateText(
            string,
            extrusionDepth: Float(fontSize) * Typography.extrusionRatio,
            font: .systemFont(ofSize: fontSize),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
    }

    private static func portraitPlane(_ portrait: CGImage) throws -> ModelEntity {
        let side = CardGeometry.height * Portrait.sideRatio
        let texture = try TextureResource(image: portrait, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))

        let plane = ModelEntity(
            mesh: .generatePlane(width: side, height: side, cornerRadius: side / 2),
            materials: [material]
        )
        plane.name = "PhotoPlane"
        plane.position = [
            CardGeometry.width / 2 - side / 2 - Portrait.trailingInset,
            .zero,
            CardGeometry.depth / 2 + CardGeometry.surfaceOffset,
        ]
        return plane
    }
}
