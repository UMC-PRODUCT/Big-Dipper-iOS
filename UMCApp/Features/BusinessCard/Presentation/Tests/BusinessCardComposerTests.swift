//
//  BusinessCardComposerTests.swift
//  BusinessCardPresentationTests
//

import BusinessCardDomain
import CoreGraphics
import CoreUIComponents
import Foundation
import RealityKit
import SwiftUI
import Testing
import UIKit
import UMCFoundation
@testable import BusinessCardPresentation

/// 합성 결과가 **실제로 프로필 값을 들고 있는지** 보는 테스트 (#1248).
///
/// 앵커 존재·치수·면 방향은 여기서 보지 않는다 — `BusinessCardTemplateContractTests`(#1246)
/// 소관이다. 성능 수치도 보지 않는다 — 스파이크가 소유한다. 여기가 답하는 질문은
/// 하나다: **「어느 앵커에 무엇이 붙었나」.**
///
/// ## 메시에서 문자열을 되읽을 수 없다
///
/// 그래서 기대 문자열로 같은 슬롯의 기준 메시를 즉석에서 구워 **지문**(폭, 정점 수)을
/// 맞춘다. `generateText` 가 결정적이라는 건 스파이크가 NFC/NFD 비교로 확인했다.
///
/// 실행: `cd UMCApp && make test SCHEME=BusinessCardPresentation`
/// (기본 `SCHEME=UMCApp` 에는 이 타겟이 없다.)
///
/// - Note: `.serialized` 인 이유 — 시뮬레이터 첫 합성이 RealityKit 런타임 초기화로
///   9–11초 걸린다. 병렬로 돌리면 그 10초짜리가 여러 개 생기고 어느 테스트가 느린지도
///   알 수 없게 된다. **이 스위트에 벽시계 단정을 넣지 마라.**
@MainActor
@Suite("BusinessCardComposer — 합성 결과", .serialized)
struct BusinessCardComposerTests {

    // MARK: - 1. 이름

    @Test("이름 앵커에 nameWithNickname 이 붙는다")
    func bindsDisplayNameToNameAnchor() async throws {
        let card = Self.card()
        let root = try await BusinessCardComposer.compose(card)

        let mesh = try #require(Self.mesh(of: .name, in: root))

        #expect(Self.fingerprint(mesh) == Self.fingerprint(card.nameWithNickname, .name))
        // 닉네임을 흘리면 `name` 만 그려진다 — 지문이 다르다는 것으로 잡는다.
        #expect(Self.fingerprint(mesh) != Self.fingerprint(card.name, .name))
    }

    // MARK: - 2. 기수 접미사

    @Test("기수 칩은 「12」가 아니라 「12기」다")
    func bindsGenerationWithSuffix() async throws {
        let card = Self.card(generation: "12")
        let root = try await BusinessCardComposer.compose(card)

        let mesh = try #require(Self.mesh(of: .generationChipLabel, in: root))
        let slot = BusinessCardTemplate.TextSlot.generationChipLabel

        #expect(Self.fingerprint(mesh) == Self.fingerprint("12기", slot))
        #expect(Self.fingerprint(mesh) != Self.fingerprint("12", slot))
    }

    // MARK: - 3. 파트 표시 이름

    @Test("모르는 파트는 원본 문자열을 그린다 (운영진으로 위장하지 않는다)")
    func bindsRawPartLabel() async throws {
        let card = Self.card(part: .admin, partRaw: "Flutter")
        let root = try await BusinessCardComposer.compose(card)

        let mesh = try #require(Self.mesh(of: .partChipLabel, in: root))
        let slot = BusinessCardTemplate.TextSlot.partChipLabel

        #expect(Self.fingerprint(mesh) == Self.fingerprint("Flutter", slot))
        #expect(Self.fingerprint(mesh) != Self.fingerprint(UMCPartType.admin.name, slot))
    }

    // MARK: - 4. 링크 당김

    @Test("빈 링크는 건너뛰고 위에서부터 당겨 채운다")
    func compactsLinksUpward() async throws {
        let card = Self.card(github: nil, linkedIn: "linkedin.com/in/umc", blog: "umc.blog")
        let root = try await BusinessCardComposer.compose(card)
        let slot = BusinessCardTemplate.TextSlot.link

        let top = try #require(Self.mesh(of: .linkTop, in: root))
        let middle = try #require(Self.mesh(of: .linkMiddle, in: root))

        #expect(Self.fingerprint(top) == Self.fingerprint("linkedin.com/in/umc", slot))
        #expect(Self.fingerprint(middle) == Self.fingerprint("umc.blog", slot))
        #expect(Self.entity(.linkBottom, in: root) == nil)
    }

    // MARK: - 5. 값 없음 = 정상

    @Test("링크가 하나도 없어도 던지지 않고 자식만 안 만든다")
    func missingValuesAreNotErrors() async throws {
        let card = Self.card(github: nil, linkedIn: nil, blog: "   ")
        let root = try await BusinessCardComposer.compose(card)

        #expect(Self.entity(.linkTop, in: root) == nil)
        #expect(Self.entity(.linkMiddle, in: root) == nil)
        #expect(Self.entity(.linkBottom, in: root) == nil)
        // 앵커 자체는 그대로 있어야 한다 — 값이 없다고 규약 prim 을 지우지 않는다.
        #expect(root.findEntity(named: BusinessCardTemplate.RequiredPrim.anchorLinkTop.rawValue)
            != nil)
    }

    // MARK: - 6. 앵커 없음 = throw

    @Test("앵커가 사라지면 조용히 넘어가지 않고 던진다")
    func missingAnchorThrows() async throws {
        let root = try await BusinessCardTemplate.load()
        let anchor = try BusinessCardTemplate.entity(.anchorName, in: root)
        anchor.removeFromParent()

        await #expect(throws: BusinessCardTemplate.TemplateError.missingAnchor("Anchor_Name")) {
            try await BusinessCardComposer.bind(
                Self.card(),
                portrait: nil,
                qrImage: nil,
                partTint: nil,
                into: root
            )
        }
    }

    // MARK: - 7. 말줄임

    @Test("폭 예산을 넘는 이름은 상자 안에서 잘린다")
    func longNameIsTruncated() async throws {
        let overflowing = "황보정민아정민아정민아/민아민아민아"
        let card = Self.card(name: overflowing, nickname: "")
        let root = try await BusinessCardComposer.compose(card)
        let slot = BusinessCardTemplate.TextSlot.name

        let width = try #require(Self.mesh(of: .name, in: root)).bounds.extents.x
        let unbounded = MeshResource.generateText(
            overflowing,
            extrusionDepth: slot.extrusionDepth,
            font: .systemFont(ofSize: CGFloat(slot.fontSize), weight: slot.weight),
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ).bounds.extents.x

        // `containerFrame` 을 빠뜨리고 `.zero` 로 부르면 이름이 카드 밖으로 삐져나간다.
        #expect(width <= slot.width)
        #expect(width < unbounded)
    }

    // MARK: - 8. 빈 이름

    @Test("이름이 공백뿐이면 자식을 만들지 않는다")
    func blankNameProducesNoEntity() async throws {
        let root = try await BusinessCardComposer.compose(Self.card(name: "   ", nickname: " "))

        // 빈 메시는 bounds 가 무한대가 된다 — 씬에 들어가면 #1247 카메라 프레이밍이
        // 무한대에 끌려가 카드가 통째로 화면 밖으로 날아간다.
        #expect(Self.entity(.name, in: root) == nil)
    }

    // MARK: - 9. 사진 없음

    @Test("사진이 없으면 템플릿 자리표시자를 건드리지 않는다")
    func absentPortraitKeepsPlaceholder() async throws {
        let root = try await BusinessCardTemplate.load()
        let portrait = try #require(
            BusinessCardTemplate.entity(.portrait, in: root) as? ModelEntity
        )
        let before = portrait.model?.materials.count

        try await BusinessCardComposer.bind(
            Self.card(),
            portrait: nil,
            qrImage: nil,
            partTint: nil,
            into: root
        )

        #expect(portrait.model?.materials.count == before)
        // 주입했다면 `UnlitMaterial` 이 된다. USD 자리표시자는 그게 아니다.
        #expect(portrait.model?.materials.first is UnlitMaterial == false)
    }

    // MARK: - 10. 사진 주입

    @Test("사진은 Portrait 에만 붙고 QRSurface 는 그대로다")
    func portraitTextureLandsOnPortraitOnly() async throws {
        let root = try await BusinessCardTemplate.load()
        try await BusinessCardComposer.bind(
            Self.card(),
            portrait: try makeImage(),
            qrImage: nil,
            partTint: nil,
            into: root
        )

        let portrait = try #require(
            BusinessCardTemplate.entity(.portrait, in: root) as? ModelEntity
        )
        let injected = try #require(portrait.model?.materials.first as? UnlitMaterial)

        #expect(injected.color.texture != nil)

        let qr = try #require(BusinessCardTemplate.entity(.qrSurface, in: root) as? ModelEntity)

        #expect(qr.model?.materials.first is UnlitMaterial == false)
    }

    // MARK: - 11. 파트 tint

    @Test("tint 는 칩 두 개에 똑같이 들어가고, 없으면 반투명 흰색이다")
    func tintPaintsBothCapsules() async throws {
        let tinted = try await BusinessCardComposer.compose(Self.card(), partTint: .red)
        let partCapsule = try #require(Self.material(of: .partChipCapsule, in: tinted))
        let generationCapsule = try #require(
            Self.material(of: .generationChipCapsule, in: tinted)
        )

        // RealityKit 은 넘긴 색을 자기 색 공간으로 옮겨 담는다 — 동적 카탈로그 색인
        // `UIColor(Color.red)` 원본과는 `==` 가 성립하지 않는다. 같은 경로로 한 번 구운
        // 기준값과 대조해야 「요청한 색이 그대로 들어갔나」를 본다.
        let requested = UnlitMaterial(color: UIColor(Color.red)).color.tint

        #expect(partCapsule.color.tint == generationCapsule.color.tint)
        #expect(partCapsule.color.tint == requested)
        #expect(Self.isTransparent(partCapsule) == false)

        let neutral = try await BusinessCardComposer.compose(Self.card(), partTint: nil)

        #expect(Self.isTransparent(try #require(Self.material(of: .partChipCapsule, in: neutral))))
        #expect(Self.isTransparent(
            try #require(Self.material(of: .generationChipCapsule, in: neutral))
        ))
    }

    // MARK: - 12. 모르는 파트 = tint 없음

    @Test("파트를 못 읽은 카드는 tint 가 없다")
    func unknownPartHasNoTint() {
        let known = Self.card(part: .front(type: .ios))
        let unknown = Self.card(part: .admin, partRaw: "Flutter")

        #expect(BusinessCardComposer.partTint(for: known) == known.part.seedColor)
        // 폴백 `.admin` 색으로 칠하면 모르는 파트가 운영진처럼 보인다.
        #expect(BusinessCardComposer.partTint(for: unknown) == nil)
    }

    // MARK: - 13. 이름 유일성

    @Test("합성 후에도 트리 이름이 유일하다")
    func composedNamesStayUnique() async throws {
        let root = try await BusinessCardComposer.compose(Self.card())
        let names = Self.names(in: root)

        // 중복이 생기면 `findEntity(named:)` 가 첫 매치만 줘서 **조용히** 깨진다.
        #expect(names.count == Set(names).count)
    }

    // MARK: - 14. 해제

    @Test("호출자가 놓으면 카드가 해제된다")
    func composedEntityDeallocates() async throws {
        let probe = try await composeAndForget(Self.card())

        // 컴포저가 static 저장소에 엔티티를 붙들고 있으면 여기서 살아 있다.
        #expect(probe() == nil)
    }

    // MARK: - 15. 취소

    @Test("취소된 작업은 끝까지 합성하지 않는다")
    func cancellationStopsComposition() async throws {
        let task = Task { try await BusinessCardComposer.compose(Self.card()) }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: - Fixture

    private func makeImage(size: Int = 8) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(UIColor.systemTeal.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return try #require(context.makeImage())
    }

    /// 합성한 뒤 강참조를 전부 버리고 약참조만 남긴다. 지역 변수를 스코프에 남겨 두면
    /// 해제 시점이 프레임에 묶여 단정이 흔들린다.
    private func composeAndForget(_ card: MyCard) async throws -> () -> Entity? {
        let root = try await BusinessCardComposer.compose(card)
        return { [weak root] in root }
    }

    private static func card(
        name: String = "김유엠",
        nickname: String = "유엠디",
        part: UMCPartType = .front(type: .ios),
        partRaw: String? = nil,
        generation: String = "12",
        github: String? = "github.com/umc",
        linkedIn: String? = "linkedin.com/in/umc",
        blog: String? = "umc.blog"
    ) -> MyCard {
        MyCard(
            memberId: "42",
            name: name,
            nickname: nickname,
            part: part,
            generation: generation,
            university: "한양대학교",
            email: "umc@example.com",
            github: github,
            linkedIn: linkedIn,
            blog: blog,
            avatarURL: nil,
            partRaw: partRaw
        )
    }

    // MARK: - Helper

    /// 기대 문자열로 같은 슬롯의 메시를 구워 지문을 뽑는다.
    /// (폭, 정점 수) 쌍이 문자열마다 사실상 유일하다 — 폭만 보면 우연히 같은 다른
    /// 문자열이 통과할 수 있어 정점 수를 같이 본다.
    private static func fingerprint(
        _ text: String,
        _ slot: BusinessCardTemplate.TextSlot
    ) -> Fingerprint {
        fingerprint(MeshResource.generateText(
            text,
            extrusionDepth: slot.extrusionDepth,
            font: .systemFont(ofSize: CGFloat(slot.fontSize), weight: slot.weight),
            containerFrame: slot.containerFrame,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        ))
    }

    private static func fingerprint(_ mesh: MeshResource) -> Fingerprint {
        Fingerprint(
            width: mesh.bounds.extents.x,
            vertexCount: mesh.contents.models
                .flatMap(\.parts)
                .reduce(0) { $0 + $1.positions.count }
        )
    }

    private struct Fingerprint: Equatable {
        let width: Float
        let vertexCount: Int
    }

    private static func entity(
        _ prim: BusinessCardComposer.ComposedPrim,
        in root: Entity
    ) -> ModelEntity? {
        root.findEntity(named: prim.rawValue) as? ModelEntity
    }

    private static func mesh(
        of prim: BusinessCardComposer.ComposedPrim,
        in root: Entity
    ) -> MeshResource? {
        entity(prim, in: root)?.model?.mesh
    }

    private static func material(
        of prim: BusinessCardComposer.ComposedPrim,
        in root: Entity
    ) -> UnlitMaterial? {
        entity(prim, in: root)?.model?.materials.first as? UnlitMaterial
    }

    private static func isTransparent(_ material: UnlitMaterial) -> Bool {
        if case .transparent = material.blending { return true }
        return false
    }

    private static func names(in entity: Entity) -> [String] {
        let own = entity.name.isEmpty ? [] : [entity.name]
        return own + entity.children.flatMap { names(in: $0) }
    }
}
