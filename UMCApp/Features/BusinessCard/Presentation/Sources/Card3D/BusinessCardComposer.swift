//
//  BusinessCardComposer.swift
//  BusinessCardPresentation
//

import BusinessCardDomain
import CoreGraphics
import CoreUIComponents
import Foundation
import RealityKit
import SwiftUI
import UIKit
import UMCFoundation

/// 베이스 USDZ 템플릿(#1246)에 프로필 값을 얹어 3D 명함 한 장을 만드는 합성기.
///
/// **앵커 이름·슬롯 폰트·좌표는 전부 ``BusinessCardTemplate`` 이 들고 있다.**
/// 여기에는 문자열 리터럴 앵커 이름도, 밀리미터 좌표도 없다 — 규약이 바뀌면 고칠 곳은
/// 템플릿(과 그걸 굽는 `tools/card-template/build_template.py`) 하나다.
///
/// ## 왜 `@MainActor` 인가
///
/// 합성에 쓰는 RealityKit API 가 **전부** `@preconcurrency @MainActor` 다 —
/// `Entity`·`ModelEntity`·`MeshResource`·`TextureResource` 와 그 생성 함수들
/// (`RealityFoundation.swiftinterface` 의 `generateText`·`generatePlane`·
/// `init(image:withName:options:)`). 백그라운드 액터에서 만들 방법이 없다.
/// 그래서 **오프메인으로 뺄 수 있는 건 사진 다운로드·디코드뿐**이고
/// (``RemoteImageLoader`` 가 Kingfisher 로 처리한다) 나머지는 메인에서 돈다.
///
/// 대신 바인딩 한 단계마다 ``breathe()`` 로 메인 런루프에 숨을 준다. 스파이크 실측
/// (`docs/claude/business-card-3d-spike.md`)에서 워밍업 이후 합성이 27–54ms 였으므로
/// 9단계로 쪼개면 한 조각이 프레임 예산(16.7ms) 안에 들어간다.
///
/// - Important: 이 모듈은 `SWIFT_STRICT_CONCURRENCY` 가 꺼져 있어 격리 위반을
///   컴파일러가 잡아 주지 않는다. `@MainActor`/`nonisolated` 를 추론에 맡기지 말고
///   명시한다.
///
/// ## 상태를 갖지 않는다
///
/// 엔티티 캐시를 두지 않는다. RealityKit 엔티티는 부모를 하나만 가지므로 캐시한 루트를
/// 두 번째 화면에 넣으면 첫 번째 화면에서 **사라진다** — 캐시 히트가 곧 버그가 된다.
/// 비싼 부분(HTTP·디코드)은 Kingfisher 가 이미 캐시하고, 명함첩 다장 문제는 #1249 의
/// 2D 스냅샷이 푼다. 무상태라서 「명함 여러 장이 오가도 누수 없음」이 자명하게 참이다.
@MainActor
public enum BusinessCardComposer {

    // MARK: - Property

    /// 사진 텍스처 목표 픽셀(긴 변). 512px RGBA ≈ 0.93MB (스파이크 실측 926–932KB).
    /// 메모리를 줄여야 하면 여기 하나만 낮춘다.
    public static let portraitPixelSize: CGFloat = 512

    // MARK: - Prim

    /// 합성이 **만들어 붙이는** 엔티티 이름.
    ///
    /// ``BusinessCardTemplate/RequiredPrim`` 이 「USDZ 에 있어야 하는 것」이라면 이쪽은
    /// 「런타임이 더하는 것」이다. 둘을 한 열거형에 섞으면 계약 테스트가 합성 산출물까지
    /// 요구하게 된다. 테스트와 #1247 이 이 이름으로 결과를 찾는다.
    public enum ComposedPrim: String, CaseIterable, Sendable {
        case name = "Text_Name"
        case university = "Text_University"
        case partChipCapsule = "Capsule_PartChip"
        case partChipLabel = "Text_PartChip"
        case generationChipCapsule = "Capsule_GenerationChip"
        case generationChipLabel = "Text_GenerationChip"
        case linkTop = "Text_LinkTop"
        case linkMiddle = "Text_LinkMiddle"
        case linkBottom = "Text_LinkBottom"
    }

    // MARK: - Function

    /// 명함 한 장을 합성해 새 루트 엔티티를 돌려준다.
    ///
    /// - Parameters:
    ///   - card: 그릴 프로필. ``ReceivedCard`` 는 `profile` 이 그대로 ``MyCard`` 라
    ///     받은 명함도 같은 경로를 탄다.
    ///   - portrait: 프로필 사진 픽셀. `nil` 이면 템플릿의 회색 자리표시자가 남는다.
    ///     URL 이 아니라 `CGImage` 를 받는 이유는 다운로드를 오프메인에 두기 위해서다 —
    ///     호출부가 ``RemoteImageLoader/cgImage(from:maxPixelSize:)`` 로 먼저 받아온다.
    ///   - qrImage: 뒷면 QR. `nil` 이면 흰 정사각이 남는다.
    ///   - partTint: 칩 캡슐 악센트. `nil` 이면 반투명 흰색(시안 기본값).
    ///     보통 ``partTint(for:)`` 가 준 값을 그대로 넘긴다.
    /// - Returns: 씬에 바로 넣을 수 있는 카드 루트. 소유권은 전적으로 호출자에게 있다.
    /// - Throws: 앵커가 없으면 ``BusinessCardTemplate/TemplateError/missingAnchor(_:)``,
    ///   번들에 에셋이 없으면 `.assetMissing`, 취소되면 `CancellationError`.
    ///   **실패를 삼키지 않는다** — 조용히 빈 카드를 돌려주는 것보다 던지는 게 낫다.
    public static func compose(
        _ card: MyCard,
        portrait: CGImage? = nil,
        qrImage: CGImage? = nil,
        partTint: Color? = nil
    ) async throws -> Entity {
        let root = try await BusinessCardTemplate.load()
        try await bind(
            card,
            portrait: portrait,
            qrImage: qrImage,
            partTint: partTint,
            into: root
        )
        return root
    }

    /// 카드의 파트 악센트 색. 서버 파트를 못 읽었으면 `nil`.
    ///
    /// ``UMCPartType`` 은 닫힌 열거형이라 모르는 파트가 `.admin` 으로 폴백되고
    /// `partRaw` 에 원본이 남는다. 그때 `seedColor` 를 쓰면 **모르는 파트가 운영진
    /// 인디고로 위장된다.** 그래서 폴백은 「색 없음」이다 — 중립 캡슐이 틀린 색보다 낫다.
    ///
    /// 합성기가 ``UMCPartType`` 을 직접 분기하지 않는 것도 같은 이유다. 파트가 늘어나도
    /// 이 함수는 그대로다.
    nonisolated public static func partTint(for card: MyCard) -> Color? {
        card.partRaw == nil ? card.part.seedColor : nil
    }

    // MARK: - Bind

    /// ``compose(_:portrait:qrImage:partTint:)`` 의 본체.
    ///
    /// 로드와 분리해 둔 이유는 테스트가 **훼손된 루트**(앵커를 지운 트리)를 넣어
    /// 「앵커 없음 = throw」를 검증할 수 있어야 하기 때문이다. `compose` 는 안에서
    /// 로드하므로 그 틈이 없다.
    static func bind(
        _ card: MyCard,
        portrait: CGImage?,
        qrImage: CGImage?,
        partTint: Color?,
        into root: Entity
    ) async throws {
        try attachText(card.displayName, slot: .name, as: .name, to: .anchorName, in: root)
        try await breathe()

        try attachText(
            card.university,
            slot: .university,
            as: .university,
            to: .anchorUniversity,
            in: root
        )
        try await breathe()

        try attachChip(
            card.partDisplayName,
            slot: .partChipLabel,
            capsule: .partChipCapsule,
            label: .partChipLabel,
            tint: partTint,
            to: .anchorPartChip,
            in: root
        )
        try await breathe()

        // 「12」가 아니라 「12기」다 — 2D(`BusinessCardFaceView`)와 같은 문자열이어야 한다.
        try attachChip(
            "\(card.generation)기",
            slot: .generationChipLabel,
            capsule: .generationChipCapsule,
            label: .generationChipLabel,
            tint: partTint,
            to: .anchorGenerationChip,
            in: root
        )
        try await breathe()

        try await attachTexture(portrait, to: .portrait, in: root)
        try await breathe()

        try attachLinks(of: card, in: root)
        try await breathe()

        try await attachTexture(qrImage, to: .qrSurface, in: root)
        try Task.checkCancellation()
    }

    /// 뒷면 링크 3줄. 값이 있는 것만 **위에서부터 당겨 채운다.**
    ///
    /// 2D `linkRow(value:icon:)` 이 nil·빈 문자열을 건너뛰는 것과 같은 규칙이다.
    /// github 이 없다고 첫 줄을 비워 두면 같은 명함이 2D 와 3D 에서 다르게 읽힌다.
    private static func attachLinks(of card: MyCard, in root: Entity) throws {
        let anchors: [(BusinessCardTemplate.RequiredPrim, ComposedPrim)] = [
            (.anchorLinkTop, .linkTop),
            (.anchorLinkMiddle, .linkMiddle),
            (.anchorLinkBottom, .linkBottom),
        ]
        let values = [card.github, card.linkedIn, card.blog]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 앵커는 값이 없어도 **전부** 확인한다. 링크 1개짜리 카드에서 앵커 실종이
        // 발견되지 않으면 3개짜리 카드가 처음 도착할 때 터진다.
        for (offset, anchor) in anchors.enumerated() {
            let target = try BusinessCardTemplate.entity(anchor.0, in: root)
            guard offset < values.count else { continue }

            attach(text: values[offset], slot: .link, named: anchor.1, to: target)
        }
    }

    /// 텍스트 슬롯 하나를 앵커에 붙인다. 값이 비면 **자식을 만들지 않는다.**
    private static func attachText(
        _ text: String,
        slot: BusinessCardTemplate.TextSlot,
        as prim: ComposedPrim,
        to anchor: BusinessCardTemplate.RequiredPrim,
        in root: Entity
    ) throws {
        let target = try BusinessCardTemplate.entity(anchor, in: root)
        attach(text: text, slot: slot, named: prim, to: target)
    }

    private static func attach(
        text: String,
        slot: BusinessCardTemplate.TextSlot,
        named prim: ComposedPrim,
        to anchor: Entity
    ) {
        guard let entity = textEntity(text, slot: slot, named: prim.rawValue) else { return }
        anchor.addChild(entity)
    }

    /// 칩 = 캡슐(밑) + 라벨(위). 앵커 z 가 이름 앵커(0.2mm)보다 얕은 0.1mm 인 이유가
    /// 이 적층이다 — 캡슐이 면 위에, 라벨이 캡슐 위에 선다.
    private static func attachChip(
        _ text: String,
        slot: BusinessCardTemplate.TextSlot,
        capsule capsulePrim: ComposedPrim,
        label labelPrim: ComposedPrim,
        tint: Color?,
        to anchor: BusinessCardTemplate.RequiredPrim,
        in root: Entity
    ) throws {
        let target = try BusinessCardTemplate.entity(anchor, in: root)
        guard let label = textEntity(text, slot: slot, named: labelPrim.rawValue),
              let mesh = label.model?.mesh else { return }

        // 폭 **예산**(`slot.width`)이 아니라 실제 잉크 폭으로 감싼다. 2D `PartChip` 이
        // 텍스트를 감싸는 방식과 같아야 「PM」 칩과 「Android」 칩의 리듬이 일치한다.
        let ink = mesh.bounds.extents.x
        let width = max(Chip.minWidth, ink + 2 * Chip.horizontalPadding)
        let height = max(Chip.minHeight, slot.frameHeight + 2 * Chip.verticalPadding)

        // 박스가 아니라 평면이다. 두께 0.1mm 짜리 박스에 반지름 ~2.9mm 를 주면
        // 어떤 메시가 나오는지 알 수 없다.
        let capsule = ModelEntity(
            mesh: .generatePlane(width: width, height: height, cornerRadius: height / 2),
            materials: [capsuleMaterial(tint: tint)]
        )
        capsule.name = capsulePrim.rawValue
        // 앵커 x 는 **leading** 기준이다 (`Anchor_Name` x + `TextSlot.name.width` 가
        // `Anchor_University` x 와 2D `PartChip` 가로 여백만큼 떨어져 있다는 데서 나온다).
        // `generatePlane` 은 원점 중심이므로 절반만큼 오른쪽으로 민다.
        capsule.position = SIMD3(width / 2, 0, 0)

        // 라벨 잉크를 캡슐 안에서 가운데로. `mesh.bounds.min.x` 는 좌측 사이드 베어링이라
        // 빼 주지 않으면 라벨이 그만큼 오른쪽으로 치우친다.
        label.position.x = (width - ink) / 2 - mesh.bounds.min.x
        label.position.z += Chip.labelLift

        target.addChild(capsule)
        target.addChild(label)
    }

    /// USD 머티리얼 슬롯을 이미지로 갈아 끼운다. 이미지가 `nil` 이면 **건드리지 않는다** —
    /// 템플릿이 구워 둔 자리표시자(사진: 회색 원, QR: 흰 정사각)가 그대로 보인다.
    /// 「사진이 없다」는 에러가 아니라 정상 상태다.
    private static func attachTexture(
        _ image: CGImage?,
        to prim: BusinessCardTemplate.RequiredPrim,
        in root: Entity
    ) async throws {
        let target = try BusinessCardTemplate.entity(prim, in: root)
        guard let image else { return }

        // 이름은 맞는데 메시가 아니면 텍스처를 붙일 자리가 없다 — 조용히 넘기면
        // 「사진 없음」과 구분이 안 된다. 앵커가 사라진 것과 같이 취급해 던진다.
        guard let surface = target as? ModelEntity else {
            throw BusinessCardTemplate.TemplateError.missingAnchor(prim.rawValue)
        }

        let texture = try await TextureResource(image: image, options: .init(semantic: .color))
        surface.model?.materials = [UnlitMaterial(texture: texture)]
    }

    // MARK: - Entity

    /// 슬롯 규약대로 텍스트 메시를 구워 `ModelEntity` 로 감싼다.
    ///
    /// 원점 보정을 **여기 한 곳에서만** 한다. 앵커마다 다른 보정값을 넣으면 좌표가
    /// 코드로 새어 나와 「좌표는 USDZ 가 들고 있다」는 규약이 무너진다.
    /// 결과가 틀어지면 고칠 곳은 `build_template.py` 의 좌표다.
    ///
    /// 실측(`ProbeTextMeshOrigin`): `containerFrame` 을 주면 메시 원점은 **컨테이너의
    /// 좌측 하단**이고 글자는 상자 안 위쪽에 눕는다 (`name` 슬롯 상자 높이 7.317mm 에
    /// 「가」 메시가 y 2.541–6.888mm). 그래서 세로로 `frameHeight/2` 만큼 내리면
    /// 앵커 y 가 **상자의 세로 중앙**이 된다.
    ///
    /// - Note: 잉크 중앙이 아니라 **상자** 중앙에 맞춘다. 잉크로 맞추면 디센더 유무에
    ///   따라 같은 줄이 문자열마다 위아래로 흔들린다.
    /// - Returns: 값이 비면 `nil`. 빈 문자열을 그대로 구우면 CoreText 가 **에러 없이**
    ///   빈 메시를 주고 그 `bounds` 는 무한대가 된다 — 그 엔티티가 씬에 들어가면
    ///   #1247 의 카메라 프레이밍이 무한대에 끌려가 카드가 화면 밖으로 날아간다.
    private static func textEntity(
        _ text: String,
        slot: BusinessCardTemplate.TextSlot,
        named name: String
    ) -> ModelEntity? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let mesh = MeshResource.generateText(
            trimmed,
            extrusionDepth: slot.extrusionDepth,
            font: .systemFont(ofSize: CGFloat(slot.fontSize), weight: slot.weight),
            containerFrame: slot.containerFrame,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        entity.name = name
        entity.position = SIMD3(0, -slot.frameHeight / 2, 0)
        return entity
    }

    /// 칩 캡슐 머티리얼. tint 가 없으면 시안 기본값인 반투명 흰색이다
    /// (시안 `명함_l` 에는 파트색이 한 픽셀도 없다 — 규약 §5).
    private static func capsuleMaterial(tint: Color?) -> UnlitMaterial {
        guard let tint else {
            var material = UnlitMaterial(color: .white)
            material.blending = .transparent(opacity: .init(floatLiteral: Chip.neutralOpacity))
            return material
        }
        return UnlitMaterial(color: UIColor(tint))
    }

    /// 메인 런루프에 한 프레임 숨을 주고 취소를 확인한다.
    ///
    /// **동시성 조정 손잡이가 여기 하나뿐이다.** 실기기 Instruments(Hangs)에서 합성 중
    /// 메인 스레드 블록이 16.7ms 를 넘으면 이 한 줄을
    /// `try await Task.sleep(for: .milliseconds(1))` 로 바꾸고 다시 잰다.
    ///
    /// - Note: `Task.yield()` 는 메인 런루프 양보를 **보장하지 않는다.** 협조적 스레드풀에
    ///   재스케줄 기회를 줄 뿐이다. 그래서 위 측정이 필요하다.
    private static func breathe() async throws {
        try Task.checkCancellation()
        await Task.yield()
    }

    // MARK: - Constant

    /// 2D ``PartChip`` 의 pt 값을 `Geometry.millimetersPerPoint` 로 환산한 것.
    /// 새 값을 만들지 않는다 — 2D 가 SSOT 다.
    private enum Chip {
        static let horizontalPadding = point(8)
        static let verticalPadding = point(3)
        static let minHeight = point(23)
        static let minWidth = point(39)

        /// 라벨을 캡슐 위로 띄우는 두께. 같은 평면에 두면 z-파이팅으로 글자가 깜빡인다.
        static let labelLift = BusinessCardTemplate.millimeters(0.02)

        /// 시안 Glass Clear 캡슐의 흰색 불투명도.
        static let neutralOpacity: Float = 0.22

        private static func point(_ value: Float) -> Float {
            BusinessCardTemplate.millimeters(
                value * BusinessCardTemplate.Geometry.millimetersPerPoint
            )
        }
    }
}

#if DEBUG
/// 합성 결과는 **테스트가 픽셀을 못 본다.** 칩 캡슐 여백, 텍스트 세로 정렬, 말줄임 모양은
/// 눈으로만 확인된다 — 그래서 프리뷰가 여기 붙어 있다.
/// (화면·인터랙션은 #1247 소관이라 별도 View 파일을 만들지 않는다.)
#Preview("3D 명함 — 합성 결과") {
    RealityView { content in
        let card = BusinessCardPreviewData.myCard
        do {
            let entity = try await BusinessCardComposer.compose(
                card,
                partTint: BusinessCardComposer.partTint(for: card)
            )
            // 카드 실물이 90mm 라 기본 카메라에서는 점으로 보인다. 프리뷰 전용 배율이다.
            entity.scale = SIMD3(repeating: 6)
            content.add(entity)
        } catch {
            assertionFailure("합성 실패: \(error)")
        }
    }
    .background(Color.black)
}
#endif
