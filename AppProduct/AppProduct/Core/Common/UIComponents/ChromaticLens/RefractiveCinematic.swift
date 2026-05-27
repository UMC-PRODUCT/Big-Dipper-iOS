//
//  RefractiveCinematic.swift
//  AppProduct
//
//  AuthBootstrap 진입 시 한 번 자동 재생되는 chromaticLens 시네마틱.
//
//  사용자가 먼저 로고를 인지한 뒤 (preDelay) 화면 중앙에서 lens 가 자동으로 피어났다 (bloom)
//  → 즉시 다시 중앙으로 잦아드는 (collapse) 3-phase 시퀀스. dwell(정지) 단계 없이 한 연속
//  keyframe timeline 으로 처리해 "정점에서 멈춘 듯한" 느낌을 제거한다. 굴곡(refraction) 과
//  무지개(dispersion + iridescence) 강도를 기본 `chromaticLens()` 보다 강하게 잡아 시네마틱
//  느낌을 강조한다.
//
//  ## Usage
//
//  ```swift
//  AuthLogoBlock()
//      .refractiveCinematic(maxRadius: 280)
//  ```
//
//  ## Timeline (총 1.5초)
//
//  - **preDelay** (0.0s → 0.4s): 정적 로고. 사용자가 UMC 로고와 슬로건을 인지할 시간.
//  - **bloom**    (0.4s → 1.0s): radius 0 → maxRadius. cubic Hermite 보간으로 가속.
//  - **collapse** (1.0s → 1.5s): radius maxRadius → 0. bloom 의 종료 속도(0이 아님)에서 자연
//    스럽게 이어받아 가운데로 모임. dwell(정지) 단계 없음.
//
//  `radius == 0` 상태에선 shader 가 모든 픽셀을 그대로 통과시켜 GPU 비용 0. preDelay 구간은
//  정적 로고가 그대로 보인다. 한 `keyframeAnimator` timeline 으로 처리하므로 bloom→collapse
//  사이에 별도 정지 구간이 생기지 않는다 (분리된 `withAnimation` 호출은 사이에 속도 0 인
//  순간이 생겨 사용자에게 "멈춤" 으로 인지됨).
//

import SwiftUI

/// 자동 재생 chromaticLens 시네마틱 ViewModifier.
///
/// 정적 로고(preDelay) → bloom → collapse 3-phase 시퀀스를 한 번 재생한다.
/// preDelay 구간은 lens 가 비활성(radius=0) 이므로 호출 대상 view 의 원본 모습이 그대로
/// 보인다 — LoginView 등 동일한 layout 의 화면으로 매끄럽게 연결되는 buffer 역할.
private struct RefractiveCinematicModifier: ViewModifier {

    // MARK: - Property

    let center: UnitPoint
    let maxRadius: CGFloat
    let refractionStrength: CGFloat
    let dispersionStrength: CGFloat
    let edgeHighlight: CGFloat
    let iridescenceStrength: CGFloat
    let preDelay: TimeInterval
    let bloomDuration: TimeInterval
    let collapseDuration: TimeInterval

    /// keyframeAnimator 트리거. mount 직후 한 번만 토글되어 시퀀스를 1회 재생한다.
    ///
    /// `.task` 가 view body re-evaluation(예: 인증 검사 완료로 인한 ViewModel 상태 변화)
    /// 마다 다시 호출되더라도, `hasStarted` 가드로 trigger 가 추가로 토글되는 것을 막아
    /// keyframe 이 재시작되며 lens 가 두 번 bloom 하는 현상을 방지한다.
    @State private var trigger: Bool = false
    @State private var hasStarted: Bool = false

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(
                initialValue: 0.0 as CGFloat,
                trigger: trigger,
                content: { view, radius in
                    // keyframeAnimator 의 content closure 는 `@Sendable` (non-isolated) 시그니처라
                    // `@MainActor` 격리된 `chromaticLens(...)` 을 직접 호출하면 Swift 6 isolation
                    // 경고가 난다. SwiftUI body 평가는 런타임상 항상 MainActor 에서 일어나므로
                    // `MainActor.assumeIsolated` 로 안전하게 격리 경계를 표명하고 호출한다.
                    MainActor.assumeIsolated {
                        view.chromaticLens(
                            center: center,
                            radius: radius,
                            refractionStrength: refractionStrength,
                            dispersionStrength: dispersionStrength,
                            edgeHighlight: edgeHighlight,
                            iridescenceStrength: iridescenceStrength
                        )
                    }
                },
                keyframes: { _ in
                    // [0] PreDelay — radius 0 유지 (정적 로고 인지 구간)
                    LinearKeyframe(0, duration: preDelay)
                    // [1] Bloom — 0 → maxRadius (easeInOut 으로 가속/감속)
                    //   CubicKeyframe 은 segment 간 velocity continuity 를 자동 계산하면서
                    //   maxRadius 정점에서 overshoot 가 생겨 "정점에서 약간 부풀었다가 줄어드는
                    //   잠시 멈춤" 으로 인지된다. SpringKeyframe(bounce: 0) 로 critically damped
                    //   spring 을 만들어 overshoot 없이 자연스럽게 가속/감속한다.
                    SpringKeyframe(
                        maxRadius,
                        duration: bloomDuration,
                        spring: .init(duration: bloomDuration, bounce: 0)
                    )
                    // [2] Collapse — maxRadius → 0 (overshoot 없는 spring 으로 즉시 감속)
                    SpringKeyframe(
                        0,
                        duration: collapseDuration,
                        spring: .init(duration: collapseDuration, bounce: 0)
                    )
                }
            )
            .task {
                // .task 는 view re-evaluation 마다 재호출될 수 있으므로 한 번만 발동.
                guard !hasStarted else { return }
                hasStarted = true
                trigger.toggle()
            }
    }
}

// MARK: - View Extension

extension View {

    /// View 에 자동 재생 chromaticLens 시네마틱을 입힌다.
    ///
    /// 정적 로고 (preDelay) → 중앙 bloom → collapse 3-phase 시퀀스를 mount 직후 한 번 재생한다.
    /// 단일 `keyframeAnimator` timeline 이라 bloom 과 collapse 사이에 정지 구간이 없다. 기본
    /// 굴곡/무지개 파라미터가 `chromaticLens()` 보다 강하게 잡혀 있어, 짧은 시간 안에 lens
    /// 효과를 또렷이 인지시키는 시네마틱 용도.
    ///
    /// - Parameters:
    ///   - center: Lens 중심의 상대 좌표(0~1). 기본 `.center` — 가운데에서 피어났다 모인다.
    ///   - maxRadius: bloom 정점에서의 lens 반경(px). 기본 280 — 화면 절반 이상을 덮는 시네마틱 크기.
    ///   - refractionStrength: 중심 magnification 강도. 기본 80 — 일반 `chromaticLens()` 의 52 보다 강함.
    ///   - dispersionStrength: R/G/B 색분산 강도. 기본 90 — 가장자리 무지개 fringe 가 또렷이 보이는 값.
    ///   - edgeHighlight: 유리 rim ring 강조. 기본 0.50.
    ///   - iridescenceStrength: lens 안쪽 무지개 광택 강도(0~1). 기본 1.0 — 시네마틱에서 무지개가
    ///     뚜렷이 드러나도록 holographic 광택을 최대로.
    ///   - preDelay: 시네마틱 시작 전 정적 로고를 보여주는 시간. 기본 0.4s — 사용자가 로고 인지.
    ///   - bloomDuration: 0 → maxRadius 까지 부풀어 오르는 시간. 기본 0.6s.
    ///   - collapseDuration: maxRadius → 0 으로 모이는 시간. 기본 0.5s.
    func refractiveCinematic(
        center: UnitPoint = .center,
        maxRadius: CGFloat = 280,
        refractionStrength: CGFloat = 80,
        dispersionStrength: CGFloat = 90,
        edgeHighlight: CGFloat = 0.50,
        iridescenceStrength: CGFloat = 1.0,
        preDelay: TimeInterval = 0.4,
        bloomDuration: TimeInterval = 0.6,
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
                preDelay: preDelay,
                bloomDuration: bloomDuration,
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
