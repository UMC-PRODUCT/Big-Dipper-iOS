//
//  BusinessCardTemplateContractTests.swift
//  BusinessCardPresentationTests
//

import Foundation
import RealityKit
import Testing
import UIKit
@testable import BusinessCardPresentation

/// 베이스 USDZ 템플릿이 앵커 규약(#1246)을 지키는지 보는 계약 테스트.
///
/// 이 이슈의 핵심 리스크는 **조용한 실패**다 — 디자이너가 prim 을 리네임하거나 단위를 잘못
/// 저작해도 앱은 에러 없이 빈 카드를 그린다. 그래서 번들 USDZ 를 실제로 로드해 이름·치수·
/// 면 방향을 단정한다.
///
/// **합성 결과(어느 앵커에 무엇이 붙었나)는 여기서 보지 않는다** — #1248 소관이다.
/// 두 관심사를 섞으면 아트워크 교체가 합성 테스트를 깨뜨린다.
///
/// 실행: `cd UMCApp && make test SCHEME=BusinessCardPresentation`
@MainActor
@Suite("BusinessCardTemplate — 번들 USDZ 앵커 계약")
struct BusinessCardTemplateContractTests {

    // MARK: - 1. 앵커 전수 존재

    @Test(
        "규약이 정한 prim 이 템플릿에 전부 있다",
        arguments: BusinessCardTemplate.RequiredPrim.allCases
    )
    func templateContainsRequiredPrim(_ prim: BusinessCardTemplate.RequiredPrim) async throws {
        let root = try await BusinessCardTemplate.load()

        #expect(root.findEntity(named: prim.rawValue) != nil)
    }

    // MARK: - 2. 이름 유일성

    @Test("prim 이름이 트리 전체에서 유일하다")
    func primNamesAreUnique() async throws {
        let root = try await BusinessCardTemplate.load()

        // findEntity(named:) 는 서브트리의 **첫 매치**를 준다. 중복이 있으면 앞뒷면 중
        // 엉뚱한 쪽에 조용히 바인딩된다.
        let names = Self.names(in: root)

        #expect(names.count == Set(names).count)
    }

    // MARK: - 3. 카드 치수

    @Test("카드 몸통이 90×50×0.6mm 로 로드된다")
    func cardBodyKeepsPhysicalSize() async throws {
        let root = try await BusinessCardTemplate.load()
        let body = try BusinessCardTemplate.entity(.cardBody, in: root)

        // metersPerUnit 을 잘못 저작하면 카드가 100배로 로드되는데 **에러가 나지 않는다.**
        let extents = try #require((body as? ModelEntity)?.model?.mesh.bounds.extents)

        #expect(abs(extents.x - BusinessCardTemplate.Geometry.width) < Self.tolerance)
        #expect(abs(extents.y - BusinessCardTemplate.Geometry.height) < Self.tolerance)
        #expect(abs(extents.z - BusinessCardTemplate.Geometry.depth) < Self.tolerance)
    }

    // MARK: - 4. 면 방향

    @Test("앞면 자식은 +Z, 뒷면 자식은 −Z 바깥에 선다")
    func facesPointOppositeDirections() async throws {
        let root = try await BusinessCardTemplate.load()
        let surface = BusinessCardTemplate.Geometry.depth / 2

        // `double3 xformOp:rotateY = (0, 180, 0)` 으로 저작하면 usdchecker 는 통과하는데
        // 회전이 먹지 않아 뒷면이 카드 안쪽에 박힌다. 스칼라 표기를 강제하는 단정이다.
        for child in try BusinessCardTemplate.entity(.faceFront, in: root).children {
            #expect(child.position(relativeTo: nil).z > surface)
        }
        for child in try BusinessCardTemplate.entity(.faceBack, in: root).children {
            #expect(child.position(relativeTo: nil).z < -surface)
        }
    }

    // MARK: - 5. 한글 슬롯 무결성

    @Test(
        "규약 슬롯으로 만든 한글 메시가 비어 있지 않고 슬롯 폭 안에 있다",
        arguments: Self.koreanSamples
    )
    func koreanSamplesProduceVisibleMesh(_ sample: KoreanSample) {
        let slot = sample.slot
        let mesh = MeshResource.generateText(
            sample.text,
            extrusionDepth: slot.fontSize * 0.05,
            font: .systemFont(ofSize: CGFloat(slot.fontSize), weight: slot.weight),
            containerFrame: slot.containerFrame,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let width = mesh.bounds.extents.x

        // 프레임 높이를 시안 lineHeight 비율(1.25×)로 주면 한글 라인이 상자에 안 들어가
        // CoreText 가 **에러 없이** 빈 메시를 돌려준다 — 그때 bounds 가 무한대가 된다.
        #expect(width.isFinite)
        #expect(width > 0)
        #expect(width <= slot.width)
    }

    // MARK: - 6. 앵커가 카드 안쪽

    @Test("모든 앵커가 카드 면 안에 있다")
    func anchorsStayInsideCard() async throws {
        let root = try await BusinessCardTemplate.load()
        let halfWidth = BusinessCardTemplate.Geometry.width / 2
        let halfHeight = BusinessCardTemplate.Geometry.height / 2

        for prim in BusinessCardTemplate.RequiredPrim.allCases where prim.isAnchor {
            let position = try BusinessCardTemplate.entity(prim, in: root).position(relativeTo: nil)

            #expect(abs(position.x) <= halfWidth, "\(prim.rawValue) x")
            #expect(abs(position.y) <= halfHeight, "\(prim.rawValue) y")
        }
    }

    // MARK: - Fixture

    /// 규약 폰트·슬롯 폭으로 실제 메시를 굽는 표본. 라틴 문자열은 1.25× 상자에서도 멀쩡히
    /// 나오므로 **영어 더미로는 이 버그가 절대 안 잡힌다** — 표본이 한글인 것이 요점이다.
    struct KoreanSample: Sendable, CustomStringConvertible {
        let text: String
        let slot: BusinessCardTemplate.TextSlot

        var description: String { text }
    }

    static let koreanSamples: [KoreanSample] = [
        // 복성(2) + 이름(3) + 닉네임(3) — 이름 슬롯이 견뎌야 하는 최장 케이스.
        .init(text: "황보정민아/민아", slot: .name),
        .init(text: "김유엠", slot: .name),
        .init(text: "서울과학기술대학교", slot: .university),
        .init(text: "12기", slot: .generationChipLabel),
    ]

    private static let tolerance: Float = 1e-5

    private static func names(in entity: Entity) -> [String] {
        let own = entity.name.isEmpty ? [] : [entity.name]
        return own + entity.children.flatMap { names(in: $0) }
    }
}

private extension BusinessCardTemplate.RequiredPrim {

    var isAnchor: Bool { rawValue.hasPrefix("Anchor_") }
}
