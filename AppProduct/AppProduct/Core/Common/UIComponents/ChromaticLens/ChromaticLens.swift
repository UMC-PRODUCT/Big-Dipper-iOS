//
//  ChromaticLens.swift
//  AppProduct
//
//  Apple `.glassEffect(.clear.interactive())` 가 노출하지 않는 굴절·색분산 강도를
//  디자이너가 직접 조정할 수 있게 해주는 재사용 ViewModifier.
//
//  내부적으로 `chromaticLens` Metal shader (Core/Mock/DesignPreview/ChromaticLens.metal)
//  를 `.layerEffect` 로 합성한다. 원형 lens 안쪽으로 sample 위치를 중심 쪽으로 당겨
//  굴절 magnification 을 만들고, R/G/B 채널마다 magnification 강도를 조금씩 달리해서
//  "굴곡질 때 무지개" — chromatic dispersion fringe — 가 자연스럽게 드러난다.
//
//  ## Usage
//
//  **인터랙티브 lens (권장)** — 손가락 위치에 lens 가 따라오고 떼면 사라진다.
//  "효과를 내가 만들어낸다" 는 인지를 주기 위해 자동 재생보다 선호된다.
//
//  ```swift
//  Logo()
//      .chromaticLensInteractive(radius: 120)
//  ```
//
//  **정적 lens** — 고정된 위치에 항상 효과. 데코레이션 용도.
//
//  ```swift
//  Image(.logoLight)
//      .resizable()
//      .aspectRatio(contentMode: .fit)
//      .frame(width: 160)
//      .chromaticLens(radius: 70)
//  ```
//
//  ## 파라미터 가이드
//
//  - `radius`: lens 영역 반경(px). 작을수록 점 위에 작은 보석 박힌 느낌, 클수록 화면 절반을 덮는 거대 굴절.
//  - `refractionStrength`: 중심 magnification 강도. 클수록 안쪽이 더 크게 부풀어 보임.
//  - `dispersionStrength`: R/G/B 채널 분리 강도. 클수록 가장자리 무지개 fringe 강해짐.
//  - `edgeHighlight`: 유리 rim ring 강조. 0 이면 ring 사라짐.
//

import SwiftUI

/// Lens 중심 좌표를 UnitPoint(0~1) 로 받아 화면 절대 좌표로 변환하고 shader uniform 으로 넘기는
/// 재사용 ViewModifier. 호출부는 절대 좌표 계산을 신경 쓰지 않아도 된다.
private struct ChromaticLensModifier: ViewModifier {

    // MARK: - Property

    let center: UnitPoint
    let radius: CGFloat
    let refractionStrength: CGFloat
    let dispersionStrength: CGFloat
    let edgeHighlight: CGFloat
    let iridescenceStrength: CGFloat
    /// 경과 초. 0 이면 셰이더의 흐르는 빛(무지개 흐름/글림/호흡)이 비활성 — 정적 lens 는 0 고정.
    let time: Double

    @State private var contentSize: CGSize = .zero

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
            }
            .layerEffect(
                ShaderLibrary.chromaticLens(
                    .float2(
                        Float(contentSize.width * center.x),
                        Float(contentSize.height * center.y)
                    ),
                    .float(Float(radius)),
                    .float(Float(refractionStrength)),
                    .float(Float(dispersionStrength)),
                    .float(Float(edgeHighlight)),
                    .float(Float(iridescenceStrength)),
                    .float(Float(time))
                ),
                maxSampleOffset: CGSize(width: radius, height: radius)
            )
    }
}

// MARK: - Interactive Modifier

/// 손가락 위치를 따라 lens 가 이동하고, 떼면 부드럽게 사라지는 인터랙티브 ViewModifier.
///
/// 사용자가 "효과를 직접 만들어낸다" 는 인지를 주기 위한 변종. 자동 재생 대비 학습 비용이 들지만,
/// 한 번 발견하면 인터랙션 자체가 재미 요소가 된다.
///
/// 내부 동작
/// - `contentShape(.rect)` 으로 투명 영역 포함 전체 bounds 가 hit-test 대상.
/// - `DragGesture(minimumDistance: 0)` — 탭만 해도 즉시 trigger.
/// - 터치 시작: `displayRadius` 0 → `maxRadius` 로 ease-out 애니메이션 (lens 가 피어나는 느낌).
/// - 터치 종료: `displayRadius` → 0 으로 ease-out (lens 가 잦아드는 느낌).
/// - `displayRadius = 0` 이면 shader 가 모든 픽셀에 대해 `dist > radius` 분기를 타 그대로 통과.
private struct ChromaticLensInteractiveModifier: ViewModifier {

    // MARK: - Property

    let maxRadius: CGFloat
    let refractionStrength: CGFloat
    let dispersionStrength: CGFloat
    let edgeHighlight: CGFloat
    let iridescenceStrength: CGFloat

    /// 현재 손가락 위치(view-local). 시작값은 화면 밖이라 lens 가 보이지 않음.
    @State private var touchLocation: CGPoint = .init(x: -10_000, y: -10_000)
    /// shader 로 넘기는 현재 반경. 0 → maxRadius 사이를 애니메이션.
    @State private var displayRadius: CGFloat = 0

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchLocation = value.location
                        if displayRadius != maxRadius {
                            withAnimation(.easeOut(duration: 0.22)) {
                                displayRadius = maxRadius
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.32)) {
                            displayRadius = 0
                        }
                    }
            )
            .layerEffect(
                ShaderLibrary.chromaticLens(
                    .float2(Float(touchLocation.x), Float(touchLocation.y)),
                    .float(Float(displayRadius)),
                    .float(Float(refractionStrength)),
                    .float(Float(dispersionStrength)),
                    .float(Float(edgeHighlight)),
                    .float(Float(iridescenceStrength)),
                    .float(0)  // time=0 — 인터랙티브 lens 는 흐르는 빛 모션 미사용
                ),
                maxSampleOffset: CGSize(width: maxRadius, height: maxRadius)
            )
    }
}

// MARK: - View Extension

extension View {

    /// View 에 chromatic dispersion lens 효과를 입힌다 (정적 위치).
    ///
    /// 원형 lens 안쪽에서 sample 위치가 중심 쪽으로 당겨져 굴절 magnification 이 발생하고,
    /// R/G/B 채널이 분리되며 가장자리에 무지개 fringe 가 나타난다.
    ///
    /// - Parameters:
    ///   - center: Lens 중심의 상대 좌표(0~1). 기본 `.center`.
    ///   - radius: Lens 영역 반경(px).
    ///   - refractionStrength: 중심 magnification 강도. 기본 52.
    ///   - dispersionStrength: R/G/B 색분산 강도. 기본 60 — 굴곡질 때 무지개가 또렷이 보이는 값.
    ///   - edgeHighlight: 유리 rim ring 강조. 기본 0.35.
    ///   - iridescenceStrength: lens 안쪽 무지개 광택 강도(0~1). 기본 0.55.
    ///     배경이 단조로워(흰색 등) chromatic dispersion 만으로는 무지개가 잘 안 드러날 때
    ///     이 값을 키워 비누거품·진주 같은 holographic 광택을 추가한다.
    ///   - time: 경과 초. 0(기본)이면 흐르는 빛(무지개 흐름/이동 글림/미세 호흡)이 비활성.
    ///     `RefractiveCinematic` 이 시간 클럭을 주입해 시네마틱에서 빛을 살아 움직이게 한다.
    func chromaticLens(
        center: UnitPoint = .center,
        radius: CGFloat,
        refractionStrength: CGFloat = 52,
        dispersionStrength: CGFloat = 60,
        edgeHighlight: CGFloat = 0.35,
        iridescenceStrength: CGFloat = 0.55,
        time: Double = 0
    ) -> some View {
        modifier(
            ChromaticLensModifier(
                center: center,
                radius: radius,
                refractionStrength: refractionStrength,
                dispersionStrength: dispersionStrength,
                edgeHighlight: edgeHighlight,
                iridescenceStrength: iridescenceStrength,
                time: time
            )
        )
    }

    /// View 에 손가락을 따라가는 인터랙티브 chromaticLens 효과를 입힌다.
    ///
    /// 사용자가 탭/드래그하면 그 위치에 lens 가 피어나고, 손을 떼면 부드럽게 사라진다.
    /// 자동 재생 대신 인터랙션으로 발견하게 만들어 효과에 대한 인지·재미를 강화하는 용도.
    ///
    /// > Note: 내부에서 `DragGesture(minimumDistance: 0)` 를 사용하므로 호출 대상 view 안쪽에
    /// > 다른 tap 인터랙션(Button 등) 이 있으면 충돌할 수 있다. **버튼이 포함되지 않은 영역**
    /// > (로고, 일러스트 등) 에만 적용하는 것을 권장.
    ///
    /// - Parameters:
    ///   - radius: 활성 시 lens 의 최대 반경(px). 작을수록 정밀한 보석 느낌, 클수록 광활한 굴절.
    ///   - refractionStrength: 중심 magnification 강도. 기본 52.
    ///   - dispersionStrength: R/G/B 색분산 강도. 기본 60.
    ///   - edgeHighlight: 유리 rim ring 강조. 기본 0.35.
    ///   - iridescenceStrength: lens 안쪽 무지개 광택 강도(0~1). 기본 0.55.
    func chromaticLensInteractive(
        radius: CGFloat,
        refractionStrength: CGFloat = 52,
        dispersionStrength: CGFloat = 60,
        edgeHighlight: CGFloat = 0.35,
        iridescenceStrength: CGFloat = 0.55
    ) -> some View {
        modifier(
            ChromaticLensInteractiveModifier(
                maxRadius: radius,
                refractionStrength: refractionStrength,
                dispersionStrength: dispersionStrength,
                edgeHighlight: edgeHighlight,
                iridescenceStrength: iridescenceStrength
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("인터랙티브 lens — 드래그하여 탐색") {
    VStack(spacing: 24) {
        Image(systemName: "sparkles")
            .font(.system(size: 96))
            .foregroundStyle(.indigo)
        Text("화면을 드래그해 보세요")
            .font(.headline)
            .foregroundStyle(.indigo)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .chromaticLensInteractive(radius: 140)
}

#Preview("정적 lens") {
    Image(systemName: "drop.fill")
        .font(.system(size: 120))
        .foregroundStyle(.indigo)
        .chromaticLens(radius: 70)
}
#endif
