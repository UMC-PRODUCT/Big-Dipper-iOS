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
//  여기에 더해 `TimelineView(.animation)` 으로 경과 시간을 셰이더에 주입해 무지개 흐름 +
//  이동 specular glint + 광택 미세 호흡(="살아있는 빛")을 더한다. 시간 클럭은 radius keyframe
//  과 독립적이며, 시네마틱이 끝나면 정지(`paused`)해 로그인 화면에서 GPU 비용을 0 으로
//  되돌린다. Reduce Motion 이 켜지면 흐르는 빛은 비활성화되고 굴절 bloom/collapse 만 재생된다.
//
//  ## Usage
//
//  ```swift
//  AuthLogoBlock()
//      .refractiveCinematic(maxRadius: 280)
//  ```
//
//  ## Timeline (총 2.3초)
//
//  - **preDelay** (0.0s → 0.4s): 흐릿한 워터마크 로고. 사용자가 UMC 로고를 인지할 시간.
//  - **bloom**    (0.4s → 1.4s): radius 0 → maxRadius. 동시에 로고가 워터마크 → 선명하게 reveal.
//  - **collapse** (1.4s → 2.3s): radius maxRadius → 0. bloom 의 종료 속도(0이 아님)에서 자연
//    스럽게 이어받아 가운데로 모임. dwell(정지) 단계 없음.
//
//  `radius == 0` 상태에선 shader 가 모든 픽셀을 그대로 통과시켜 GPU 비용 0. preDelay 구간은
//  정적 로고가 그대로 보인다. 한 `keyframeAnimator` timeline 으로 처리하므로 bloom→collapse
//  사이에 별도 정지 구간이 생기지 않는다 (분리된 `withAnimation` 호출은 사이에 속도 0 인
//  순간이 생겨 사용자에게 "멈춤" 으로 인지됨).
//

import SwiftUI

/// 시네마틱 한 프레임의 애니메이션 상태.
///
/// `radius`(렌즈 반경)와 `logoOpacity`(reveal 투명도)를 하나의 `keyframeAnimator` 의 두
/// `KeyframeTrack` 으로 함께 보간한다. 렌즈가 커지는 동안 로고가 흐릿한 워터마크에서 선명하게
/// 차올라, 렌즈가 전환을 가린 채 reveal 되는 연출을 만든다.
private struct CinematicState {
    var radius: CGFloat
    var logoOpacity: Double
}

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
    /// reveal 시작 투명도 — preDelay 동안 로고가 흐릿한 워터마크로 보이는 정도(0~1).
    /// bloom 동안 1.0 으로 차올라 렌즈가 덮는 사이 선명해지고, collapse 후 선명 유지.
    let revealStartOpacity: Double

    /// keyframeAnimator 트리거. mount 직후 한 번만 토글되어 시퀀스를 1회 재생한다.
    ///
    /// `.task` 가 view body re-evaluation(예: 인증 검사 완료로 인한 ViewModel 상태 변화)
    /// 마다 다시 호출되더라도, `hasStarted` 가드로 trigger 가 추가로 토글되는 것을 막아
    /// keyframe 이 재시작되며 lens 가 두 번 bloom 하는 현상을 방지한다.
    @State private var trigger: Bool = false
    @State private var hasStarted: Bool = false
    /// 흐르는 빛 시간 클럭의 기준점. 시네마틱 시작 시 갱신한다.
    @State private var startDate: Date = .now
    /// 흐르는 빛 시간 클럭 on/off. 시네마틱 동안만 true → 종료 후 TimelineView 정지(perf 0).
    @State private var isLightActive: Bool = false

    /// 접근성 — Reduce Motion 시 흐르는 빛을 비활성(굴절 bloom/collapse 는 유지)한다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    func body(content: Content) -> some View {
        // TimelineView 가 매 프레임 경과 시간을 셰이더에 공급해 흐르는 빛을 구동한다.
        // radius 는 keyframeAnimator 가, time 은 이 시간 클럭이 — 서로 독립적으로 흐른다.
        // `paused: !isLightActive` 로 시네마틱 종료 후 tick 을 멈춰 GPU 비용을 0 으로 되돌린다.
        TimelineView(.animation(paused: !isLightActive)) { timeline in
            cinematicLens(content, now: timeline.date)
        }
        .task {
            // .task 는 view re-evaluation 마다 재호출될 수 있으므로 한 번만 발동.
            guard !hasStarted else { return }
            hasStarted = true
            startDate = .now

            // Reduce Motion 이면 시간 클럭을 켜지 않아 흐르는 빛이 비활성(굴절 bloom 만 재생).
            guard !reduceMotion else {
                trigger.toggle()
                return
            }

            isLightActive = true
            trigger.toggle()

            // 시네마틱 총 길이 후 시간 클럭 정지 → morph 된 로그인 화면에서 GPU 비용 0.
            let total = preDelay + bloomDuration + collapseDuration
            try? await Task.sleep(for: .seconds(total))
            isLightActive = false
        }
    }

    // MARK: - Function

    /// 경과 시간(`now − startDate`)을 셰이더의 `time` 으로 주입한 chromaticLens 시네마틱 본체.
    ///
    /// `body` 의 `TimelineView` 클로저를 **단일 표현식**으로 유지하기 위해 분리한다 —
    /// keyframeAnimator + ternary + `MainActor.assumeIsolated` 가 한 클로저에 모이면
    /// 타입체커가 `TimelineView` 의 `Content` 제네릭을 추론하지 못한다.
    private func cinematicLens(_ content: Content, now: Date) -> some View {
        // 시간 클럭이 꺼져 있으면 0 → 셰이더의 흐르는 빛 정지 (정적 호출부와 동일 경로).
        let elapsed: Double = isLightActive ? now.timeIntervalSince(startDate) : 0

        return content
            .keyframeAnimator(
                initialValue: CinematicState(radius: 0, logoOpacity: revealStartOpacity),
                trigger: trigger,
                content: { view, state in
                    // keyframeAnimator 의 content closure 는 `@Sendable` (non-isolated) 시그니처라
                    // `@MainActor` 격리된 `chromaticLens(...)` 을 직접 호출하면 Swift 6 isolation
                    // 경고가 난다. SwiftUI body 평가는 런타임상 항상 MainActor 에서 일어나므로
                    // `MainActor.assumeIsolated` 로 안전하게 격리 경계를 표명하고 호출한다.
                    MainActor.assumeIsolated {
                        view
                            // 워터마크 → reveal: 렌즈가 sampling 하기 전에 opacity 를 적용해
                            // 흐릿한 로고가 그대로 굴절되고, bloom 동안 선명하게 차오른다.
                            .opacity(state.logoOpacity)
                            .chromaticLens(
                                center: center,
                                radius: state.radius,
                                refractionStrength: refractionStrength,
                                dispersionStrength: dispersionStrength,
                                edgeHighlight: edgeHighlight,
                                iridescenceStrength: iridescenceStrength,
                                time: elapsed
                            )
                    }
                },
                keyframes: { _ in
                    // radius 트랙 — 렌즈 반경. preDelay 0 유지 → bloom → collapse.
                    KeyframeTrack(\.radius) {
                        // [0] PreDelay — radius 0 유지 (워터마크 로고 인지 구간)
                        LinearKeyframe(0, duration: preDelay)
                        // [1] Bloom — 0 → maxRadius. SpringKeyframe(bounce: 0) 로 critically
                        //   damped spring 을 만들어 정점 overshoot 없이 자연스럽게 가속/감속한다.
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
                    // logoOpacity 트랙 — reveal. preDelay 동안 흐릿하게 유지 → bloom 동안 1.0 으로
                    // 차올라 렌즈가 덮는 사이 선명해지고 → collapse 후 선명 유지.
                    KeyframeTrack(\.logoOpacity) {
                        LinearKeyframe(revealStartOpacity, duration: preDelay)
                        LinearKeyframe(1.0, duration: bloomDuration)
                        LinearKeyframe(1.0, duration: collapseDuration)
                    }
                }
            )
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
    ///   - preDelay: 시네마틱 시작 전 흐릿한 워터마크 로고를 보여주는 시간. 기본 0.4s.
    ///   - bloomDuration: 0 → maxRadius 까지 부풀어 오르는 시간. 기본 1.0s.
    ///   - collapseDuration: maxRadius → 0 으로 모이는 시간. 기본 0.9s.
    ///   - revealStartOpacity: 렌즈 전 로고의 워터마크 투명도(0~1). 기본 0.18 — bloom 동안 1.0
    ///     으로 차올라 렌즈가 덮는 사이 선명하게 reveal 된다.
    func refractiveCinematic(
        center: UnitPoint = .center,
        maxRadius: CGFloat = 280,
        refractionStrength: CGFloat = 80,
        dispersionStrength: CGFloat = 90,
        edgeHighlight: CGFloat = 0.50,
        iridescenceStrength: CGFloat = 1.0,
        preDelay: TimeInterval = 0.4,
        bloomDuration: TimeInterval = 1.0,
        collapseDuration: TimeInterval = 0.9,
        revealStartOpacity: Double = 0.18
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
                collapseDuration: collapseDuration,
                revealStartOpacity: revealStartOpacity
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("자동 시네마틱 — 살아있는 빛(흐름+글림+호흡)") {
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
