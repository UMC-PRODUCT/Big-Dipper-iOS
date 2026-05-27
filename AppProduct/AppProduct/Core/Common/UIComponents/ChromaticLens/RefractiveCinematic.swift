//
//  RefractiveCinematic.swift
//  AppProduct
//
//  AuthBootstrap 진입 시 한 번 자동 재생되는 chromaticLens 시네마틱.
//
//  사용자 인터랙션 없이 화면 중앙에서 lens 가 자동으로 피어났다 (bloom) → 잠시 머물렀다 (dwell)
//  → 다시 중앙으로 잦아드는 (collapse) 3-phase 시퀀스. 굴곡(refraction) 과 무지개(dispersion +
//  iridescence) 강도를 기본 `chromaticLens()` 보다 강하게 잡아 시네마틱 느낌을 강조한다.
//
//  ## Usage
//
//  ```swift
//  AuthLogoBlock()
//      .refractiveCinematic(maxRadius: 240)
//  ```
//
//  ## Timeline
//
//  - **bloom**   (0.0s → 1.0s): radius 0 → maxRadius. ease-out 으로 가운데에서 부풀어 오름.
//  - **dwell**   (1.0s → 1.4s): radius 유지. 사용자가 효과를 인지할 시간.
//  - **collapse**(1.4s → 1.9s): radius maxRadius → 0. ease-in 으로 가운데로 모임.
//
//  총 1.9초. `radius == 0` 상태에선 shader 가 모든 픽셀을 그대로 통과시켜 GPU 비용 0.
//

import SwiftUI

/// 자동 재생 chromaticLens 시네마틱 ViewModifier.
///
/// 중앙에서 피어났다 잦아드는 단일 wave 를 한 번 재생한 후, radius=0 상태로 멈춘다.
/// 호출부는 wave 종료 타이밍과 별개로 자체 라우팅을 진행하면 된다 — modifier 는 시각 효과만 책임.
private struct RefractiveCinematicModifier: ViewModifier {

    // MARK: - Property

    let center: UnitPoint
    let maxRadius: CGFloat
    let refractionStrength: CGFloat
    let dispersionStrength: CGFloat
    let edgeHighlight: CGFloat
    let iridescenceStrength: CGFloat
    let bloomDuration: TimeInterval
    let dwellDuration: TimeInterval
    let collapseDuration: TimeInterval

    @State private var displayRadius: CGFloat = 0

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .chromaticLens(
                center: center,
                radius: displayRadius,
                refractionStrength: refractionStrength,
                dispersionStrength: dispersionStrength,
                edgeHighlight: edgeHighlight,
                iridescenceStrength: iridescenceStrength
            )
            .task {
                await runCinematic()
            }
    }

    // MARK: - Private

    /// 3-phase 시네마틱 시퀀스. mount 직후 한 번만 재생된다.
    @MainActor
    private func runCinematic() async {
        // [1] Bloom — 중앙에서 부풀어 오름
        withAnimation(.easeOut(duration: bloomDuration)) {
            displayRadius = maxRadius
        }
        try? await Task.sleep(for: .seconds(bloomDuration + dwellDuration))

        // [2] Collapse — 다시 중앙으로 모임
        withAnimation(.easeIn(duration: collapseDuration)) {
            displayRadius = 0
        }
    }
}

// MARK: - View Extension

extension View {

    /// View 에 자동 재생 chromaticLens 시네마틱을 입힌다.
    ///
    /// 중앙에서 lens 가 자동으로 피어났다 (bloom) → 머물렀다 (dwell) → 잦아드는 (collapse)
    /// 단일 wave 를 mount 직후 한 번 재생한다. 기본 굴곡/무지개 파라미터가 `chromaticLens()`
    /// 보다 강하게 잡혀 있어, 짧은 시간 안에 lens 효과를 또렷이 인지시키는 시네마틱 용도.
    ///
    /// - Parameters:
    ///   - center: Lens 중심의 상대 좌표(0~1). 기본 `.center` — 가운데에서 피어났다 모인다.
    ///   - maxRadius: bloom 정점에서의 lens 반경(px). 기본 240 — 화면 절반 가량을 덮는 시네마틱 크기.
    ///   - refractionStrength: 중심 magnification 강도. 기본 80 — 일반 `chromaticLens()` 의 52 보다 강함.
    ///   - dispersionStrength: R/G/B 색분산 강도. 기본 90 — 가장자리 무지개 fringe 가 또렷이 보이는 값.
    ///   - edgeHighlight: 유리 rim ring 강조. 기본 0.50.
    ///   - iridescenceStrength: lens 안쪽 무지개 광택 강도(0~1). 기본 0.85 — 시네마틱에서 무지개가
    ///     뚜렷이 드러나도록 holographic 광택을 강하게.
    ///   - bloomDuration: 0 → maxRadius 까지 부풀어 오르는 시간. 기본 1.0s.
    ///   - dwellDuration: maxRadius 에서 머무르는 시간. 기본 0.4s.
    ///   - collapseDuration: maxRadius → 0 으로 모이는 시간. 기본 0.5s.
    func refractiveCinematic(
        center: UnitPoint = .center,
        maxRadius: CGFloat = 240,
        refractionStrength: CGFloat = 80,
        dispersionStrength: CGFloat = 90,
        edgeHighlight: CGFloat = 0.50,
        iridescenceStrength: CGFloat = 0.85,
        bloomDuration: TimeInterval = 1.0,
        dwellDuration: TimeInterval = 0.4,
        collapseDuration: TimeInterval = 0.5
    ) -> some View {
        modifier(
            RefractiveCinematicModifier(
                center: center,
                maxRadius: maxRadius,
                refractionStrength: refractionStrength,
                dispersionStrength: dispersionStrength,
                edgeHighlight: edgeHighlight,
                iridescenceStrength: iridescenceStrength,
                bloomDuration: bloomDuration,
                dwellDuration: dwellDuration,
                collapseDuration: collapseDuration
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("자동 시네마틱 — 가운데 bloom → collapse") {
    VStack(spacing: 24) {
        Image(systemName: "sparkles")
            .font(.system(size: 96))
            .foregroundStyle(.indigo)
        Text("자동 재생")
            .font(.headline)
            .foregroundStyle(.indigo)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .refractiveCinematic()
}
#endif
