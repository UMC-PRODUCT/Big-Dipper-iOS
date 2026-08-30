//
//  BusinessCardTemplate.swift
//  BusinessCardPresentation
//

import CoreGraphics
import Foundation
import RealityKit
import UIKit

/// 3D 명함 베이스 USDZ 템플릿의 바인딩 계약 (#1246).
///
/// **에셋과 코드가 같이 움직여야 하는 지점은 전부 여기 있다.**
/// `Resources/BusinessCardTemplate.usdz` 를 고치면 이 파일을, 이 파일을 고치면
/// `tools/card-template/build_template.py` 를 같이 고친다. 셋이 어긋나면
/// ``BusinessCardTemplateContractTests`` 가 실패한다 — 런타임에 조용히 빈 카드가 나오는
/// 대신 테스트가 먼저 깨지도록 만든 장치다.
///
/// 좌표계: 원점 = 카드 중심 · +Y 위 · **앞면 = +Z** · 단위 = 미터.
/// 규약 표의 값은 전부 밀리미터이고 시안 `명함_l`(372×205pt)을 `0.243902 mm/pt`
/// (높이 기준 50/205)로 환산한 것이다. 임의로 정한 좌표는 없다.
///
/// 앵커의 **좌표는 여기 없다** — 위치는 USDZ 가 들고 있고 런타임은 이름으로만 찾는다.
/// 좌표를 코드에도 적으면 에셋과 어긋날 수 있는 지점이 하나 더 생긴다.
///
/// 규약 전문: `docs/claude/business-card-3d-anchor-contract.md`
public enum BusinessCardTemplate {

    // MARK: - Error

    public enum TemplateError: Error, Equatable {

        /// 번들에 템플릿 에셋이 없다. 리소스 배선(`presentationResources`)이 끊긴 경우다.
        case assetMissing(String)

        /// 규약 prim 이 템플릿에 없다. 디자이너가 prim 을 지우거나 이름을 바꾼 경우다.
        ///
        /// 「바인딩할 값이 없다」(`github == nil` 등)와 구분한다 — 그쪽은 정상 경로라
        /// 자식을 만들지 않을 뿐 에러가 아니다.
        case missingAnchor(String)
    }

    // MARK: - Geometry

    /// 카드 실물 치수. 90×50mm 는 국내 표준 명함이고 시안 종횡비(1.8146)와 0.8% 안에서 같다.
    public enum Geometry {
        public static let width: Float = millimeters(90)
        public static let height: Float = millimeters(50)
        public static let depth: Float = millimeters(0.6)

        /// 시안 `cardRadius` 34pt 환산. 실물 인쇄 명함 관례(3mm)보다 크다 — 시안을 따른다.
        public static let cornerRadius: Float = millimeters(8.293)

        /// 시안 pt → mm 환산 배율(높이 기준). 새 앵커를 더할 때 이 값으로 환산한다.
        public static let millimetersPerPoint: Float = 50.0 / 205.0
    }

    // MARK: - Prim

    /// 템플릿에 **반드시** 있어야 하는 prim. 하나라도 없으면 합성이 던진다.
    /// 계약 테스트가 이 목록을 그대로 순회한다.
    ///
    /// 이름은 트리 전체에서 유일해야 한다 — `Entity.findEntity(named:)` 가 첫 매치를
    /// 돌려주므로 앞뒷면에 같은 이름이 있으면 조용히 엉뚱한 면에 바인딩된다.
    /// 링크 3줄에 숫자 접미사를 쓰지 않는 것도 같은 이유다: 번호가 아니라 **위치**가 뜻이다.
    public enum RequiredPrim: String, CaseIterable, Sendable {
        case cardBody = "CardBody"
        case faceFront = "Face_Front"
        case faceBack = "Face_Back"
        case portrait = "Portrait"
        case qrSurface = "QRSurface"
        case anchorName = "Anchor_Name"
        case anchorUniversity = "Anchor_University"
        case anchorPartChip = "Anchor_PartChip"
        case anchorGenerationChip = "Anchor_GenerationChip"
        case anchorLinkTop = "Anchor_LinkTop"
        case anchorLinkMiddle = "Anchor_LinkMiddle"
        case anchorLinkBottom = "Anchor_LinkBottom"
    }

    // MARK: - Text Slot

    /// 텍스트 슬롯의 폭 예산·폰트. `containerFrame` 이 이 값으로 말줄임을 건다.
    ///
    /// 모든 슬롯은 좌측 정렬 단일 줄이고 폭 초과는 `.byTruncatingTail` 로 CoreText 가 자른다.
    /// 자체 축소(shrink-to-fit)는 3D 텍스트 메시에 대응물이 없어 쓰지 않는다.
    public struct TextSlot: Sendable {

        /// 프레임 높이 ÷ 폰트 크기.
        ///
        /// - Important: **1.5 여야 한다.** 시안 lineHeight 비율(title3 = 1.25×)로 주면
        ///   한글 폴백 폰트의 라인이 상자에 안 들어가 CoreText 가 **에러 없이 빈 메시**를
        ///   돌려준다. 라틴은 멀쩡히 나오므로 영어 더미로는 절대 안 잡힌다 —
        ///   계약 테스트가 `황보정민아/민아` 표본으로 이 값을 지킨다.
        public static let frameHeightRatio: Float = 1.5

        public let fontSize: Float
        public let width: Float
        public let weight: UIFont.Weight

        public var frameHeight: Float { fontSize * Self.frameHeightRatio }

        /// `MeshResource.generateText(extrusionDepth:)` 에 넘기는 두께.
        ///
        /// 폰트 크기에 비례한다 — 고정값을 쓰면 작은 슬롯(칩 라벨 2.927mm)에서만 글자가
        /// 두꺼워 보인다. 5% 는 스파이크가 쓴 값이고 카드 두께(0.6mm)를 넘지 않는다.
        public var extrusionDepth: Float { fontSize * 0.05 }

        /// `MeshResource.generateText(containerFrame:)` 에 그대로 넘기는 상자.
        public var containerFrame: CGRect {
            CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(frameHeight))
        }

        public init(fontSize: Float, width: Float, weight: UIFont.Weight) {
            self.fontSize = fontSize
            self.width = width
            self.weight = weight
        }

        /// `displayName` — 닉네임이 있으면 `"이름/닉네임"`. 한글 8자까지 안 잘린다.
        public static let name = TextSlot(
            fontSize: millimeters(4.878),
            width: millimeters(34.000),
            weight: .semibold
        )

        /// `university`. 이름 줄 오른쪽으로 흘러가므로 이 폭은 **최악 케이스 잔여분**이다.
        public static let university = TextSlot(
            fontSize: millimeters(3.171),
            width: millimeters(25.270),
            weight: .regular
        )

        /// 파트 칩 라벨. 자연 잉크 폭보다 5% 넉넉해야 CoreText 가 말줄임을 걸지 않는다.
        public static let partChipLabel = TextSlot(
            fontSize: millimeters(2.927),
            width: millimeters(12.500),
            weight: .regular
        )

        /// 기수 칩 라벨 (`"12기"`).
        public static let generationChipLabel = TextSlot(
            fontSize: millimeters(2.927),
            width: millimeters(8.000),
            weight: .regular
        )

        /// 뒷면 링크 3줄 공용. 아이콘(4.390) + 간격(1.951)을 뺀 나머지 폭이다.
        public static let link = TextSlot(
            fontSize: millimeters(3.171),
            width: millimeters(54.879),
            weight: .regular
        )
    }

    // MARK: - Material

    /// USD 머티리얼 슬롯. 템플릿에는 **이 셋만** 존재한다.
    ///
    /// 칩 캡슐과 텍스트는 합성이 만드는 엔티티라 USD prim 이 없다. 파트 악센트는
    /// 칩 캡슐의 런타임 tint 하나로만 들어가며 기본값은 `nil` 이다 —
    /// 시안 `명함_l` 에 파트색이 한 픽셀도 없기 때문이다. 색 매핑의 단일 진실 원천은
    /// `UMCPartType.seedColor` 이고 이 규약은 새 색을 만들지 않는다.
    public enum MaterialSlot: String, CaseIterable, Sendable {

        /// `CardBody` 앞뒤 공용. 인디고 그라데이션을 구워 두었고 런타임에 바꾸지 않는다.
        case cardSurface = "CardSurface"

        /// `Portrait`. 런타임에 `avatarURL` 이미지를 baseColor 텍스처로 주입한다.
        case portraitSurface = "PortraitSurface"

        /// `QRSurface`. 흰색 고정 — 주입에 실패해도 흰 정사각이 남아
        /// 「빈 카드」가 아니라 「QR 없음」으로 보인다.
        case qrSurface = "QRSurface"
    }

    // MARK: - Function

    /// 밀리미터를 RealityKit 좌표(미터)로 옮긴다.
    ///
    /// 규약 표가 전부 mm 라 상수를 mm 로 적고 여기서 한 번만 나눈다 — 코드에 `0.0048` 같은
    /// 값이 흩어지면 표와 대조가 불가능해진다.
    public static func millimeters(_ value: Float) -> Float { value / 1_000 }

    /// 번들에 실린 베이스 템플릿 URL.
    ///
    /// `Bundle.module` 은 **선언한 모듈의 번들로만** 해석되므로 이 접근자는
    /// `BusinessCardPresentation` 안에 살아야 한다 — 테스트 타겟에서 직접 부르면
    /// 테스트 번들을 뒤지다 실패한다.
    public static var bundledURL: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: resourceName,
                withExtension: resourceExtension
            ) else {
                throw TemplateError.assetMissing(resourceName)
            }
            return url
        }
    }

    /// 템플릿을 로드해 카드 루트 엔티티를 돌려준다.
    ///
    /// `Entity(contentsOf:)` 는 파일을 **이름 없는 래퍼 엔티티**로 감싸 돌려준다.
    /// 그래서 규약 prim 은 전부 ``entity(_:in:)`` 로 찾는다 — 루트 이름에 기대면 안 된다.
    @MainActor
    public static func load() async throws -> Entity {
        try await Entity(contentsOf: bundledURL)
    }

    /// 규약 prim 을 찾아 돌려준다. 없으면 던진다.
    @MainActor
    public static func entity(_ prim: RequiredPrim, in root: Entity) throws -> Entity {
        guard let entity = root.findEntity(named: prim.rawValue) else {
            throw TemplateError.missingAnchor(prim.rawValue)
        }
        return entity
    }

    // MARK: - Private

    private static let resourceName = "BusinessCardTemplate"
    private static let resourceExtension = "usdz"
}
