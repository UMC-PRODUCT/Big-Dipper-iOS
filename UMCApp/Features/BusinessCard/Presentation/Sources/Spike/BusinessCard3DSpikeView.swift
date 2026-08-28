//
//  BusinessCard3DSpikeView.swift
//  BusinessCardPresentation
//
//  Created by One on 8/28/26.
//

#if DEBUG
import BusinessCardDomain
import RealityKit
import SwiftUI

/// 3D 명함 Phase 0 검증(#1245)을 **눈으로** 확인하는 하네스 화면.
///
/// 숫자는 `BusinessCard3DSpikeTests` 가 재고, 이 화면은 테스트가 못 재는 것 — 한글 글리프가
/// 실제로 읽히는지 — 을 실기기에서 보기 위한 것이다. 라우터에 연결하지 않는다.
/// 확인이 필요하면 `#Preview` 를 열거나 임시로 아무 화면에 `.sheet` 로 띄운다.
///
/// 회전은 `realityViewCameraControls(.orbit)` 로 대신한다. 제품 회전(드래그 yaw/pitch·자이로)은
/// #1247 소관이라 여기서 만들지 않는다.
public struct BusinessCard3DSpikeView: View {

    // MARK: - Property

    private let card: MyCard
    @State private var fontSize: CGFloat = 0.006
    @State private var probes: [TextMeshProbe] = []

    // MARK: - Init

    public init(card: MyCard = BusinessCardPreviewData.myCard) {
        self.card = card
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            RealityView { content in
                content.camera = .virtual
                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = 30
                camera.position = [.zero, .zero, 0.2]
                content.add(camera)
                content.add(cardEntity)
            }
            // 폰트 크기를 바꾸면 메시를 다시 만들어야 한다. update: 로 자식을 갈아 끼우는 대신
            // 씬을 통째로 다시 세운다 — 하네스라 프레임 비용이 문제되지 않는다.
            .id(fontSize)
            .realityViewCameraControls(.orbit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)

            controls
        }
        .task { probes = BusinessCard3DSpike.probeKoreanText(fontSizes: [fontSize]) }
    }

    // MARK: - Private

    /// `Text` 보간에 다 넣으면 타입 체커가 터진다 — 문자열은 여기서 만든다.
    private func summary(of probe: TextMeshProbe) -> String {
        let width = String(format: "%.1f", probe.extents.x * 1_000)
        let height = String(format: "%.1f", probe.extents.y * 1_000)
        let elapsed = String(format: "%.2f", probe.milliseconds)
        let warning = probe.isDegenerate ? " ⚠️ 빈 메시" : ""
        return "\(probe.label) · \(elapsed)ms · \(width)×\(height)mm"
            + " · 정점 \(probe.vertexCount)\(warning)"
    }

    private var cardEntity: Entity {
        (try? BusinessCard3DSpike.composeCard(card, fontSize: fontSize)) ?? Entity()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 폰트 크기를 실물 명함 스케일(6mm)부터 RealityKit 샘플 스케일(50mm)까지 훑는다.
            // 작은 쪽에서 글리프가 무너지면 그게 이 스파이크의 핵심 결론이 된다.
            Slider(value: $fontSize, in: 0.002...0.05) {
                Text("폰트 크기")
            }
            Text("폰트 " + String(format: "%.1f", fontSize * 1_000) + "mm")
                .font(.caption.monospacedDigit())

            ForEach(probes, id: \.label) { probe in
                Text(summary(of: probe))
                    .font(.caption2.monospaced())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .onChange(of: fontSize) { _, size in
            probes = BusinessCard3DSpike.probeKoreanText(fontSizes: [size])
        }
    }
}

#Preview("3D 명함 스파이크") {
    BusinessCard3DSpikeView()
}
#endif
