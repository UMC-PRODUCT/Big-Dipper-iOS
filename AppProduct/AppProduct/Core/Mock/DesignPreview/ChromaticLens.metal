//
//  ChromaticLens.metal
//  AppProduct
//
//  커스텀 chromatic dispersion + 굴절 셰이더 (Apple `.clear.interactive()` 의 한계를 우회하기 위한 PoC).
//  SwiftUI 의 .layerEffect 로 적용되며, lens 의 중심·반경·굴절 강도·색분산 강도·edge highlight 를
//  uniform 으로 받아 pixel 단위로 분광 lensing 을 직접 계산한다.
//
//  동작 원리
//  1. 각 destination pixel 의 lens 중심까지 거리(dist)와 정규화 위치(0~1) 를 구한다.
//  2. lens 바깥(dist > radius) 은 layer 를 그대로 통과 — 영향 0.
//  3. lens 안쪽은 spherical 굴절 곡선(curve = normalized^2)을 따라 sampling point 를 중심 쪽으로 당긴다.
//     → 중심은 그대로, 가장자리로 갈수록 더 많이 휘어 magnification 효과 발생.
//  4. R / G / B 채널마다 굴절 강도를 살짝 다르게 줘서 sample 위치를 달리한다(=색분산).
//     실제 유리 dispersion 처럼 blue 가 더 많이, red 가 더 적게 휜다.
//  5. 가장자리에는 smoothstep 으로 얇은 highlight ring 을 더해 유리 rim 느낌을 추가.
//  6. lens 안쪽에 각도+반경 기반 HSV pastel 을 합성해 진주·비누거품 같은 무지개 광택을 더한다.
//  7. time uniform(경과 초) 으로 무지개 흐름 + 이동 specular glint + 광택 미세 호흡을 구동해
//     "살아있는 빛" 을 더한다. time=0 이면 이 모션은 비활성 — 정적 호출부와 픽셀 단위로 동일.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 chromaticLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 center,
    float radius,
    float refractionStrength,
    float dispersionStrength,
    float edgeHighlight,
    float iridescenceStrength,
    float time
) {
    float2 toCenter = position - center;
    float dist = length(toCenter);

    // Outside the lens — or lens too small to render — pass through unchanged.
    // `radius < 5.0` 가드는 `SpringKeyframe(bounce: 0)` 의 collapse 종료 시 발생하는 numerical
    // residue (정확히 0 으로 수렴 못 하고 0.5~3.0px 의 작은 lens 잔여가 영구히 남는 현상) 가
    // 정중앙 몇 픽셀에 작은 굴절+iridescence 를 남기는 artifact 를 방어한다. Swift 측
    // RefractiveCinematic 의 radius clamp 와 ChromaticLens `.layerEffect(isEnabled:)` 가드
    // 와 같은 임계값으로 묶어 삼중 안전망 — 5px 미만 lens 는 시각적으로 의미 없으므로 통과.
    if (radius < 5.0 || dist > radius) {
        return layer.sample(position);
    }

    float normalized = dist / radius;

    // Spherical lens 굴절 곡선 — 중심 0, 가장자리 1 (가장자리로 갈수록 강하게 휘어짐).
    float refractCurve = pow(normalized, 2.0);
    // Dispersion 곡선 — 중간 영역에서 무지개 fringe 가 드러나고,
    // **가장자리(normalized > 0.85)에서는 smoothstep 으로 0 으로 fade** 한다.
    // 이렇게 하지 않으면 lens 가 view 가장자리에 가까울 때 dispersion sample 좌표가
    // 텍스처 밖으로 나가 R/G/B 중 한 채널이 0 으로 떨어지고, 나머지 두 채널이 합쳐져
    // cyan/magenta fringe 가 화면 가장자리에 박혀 보이는 artifact 가 생긴다.
    float dispCurve = pow(normalized, 1.2)
                    * (1.0 - smoothstep(0.85, 1.0, normalized));

    // 채널별 magnification factor.
    //  - baseK 가 작을수록 sample 이 중심 쪽으로 더 당겨짐 = 더 강한 magnification.
    //  - red 는 덜 휘고(kR 큼), blue 는 더 휨(kB 작음) — 실제 유리 dispersion 방향.
    //  - dispersion 진폭은 baseK 기준 양쪽 여유분(min(baseK, 1-baseK)) 으로 자동 clamp 해
    //    kB 가 음수(=반대편 sample) 가 되지 않도록 안전 보장.
    float baseK = 1.0 - refractionStrength * 0.01 * refractCurve;
    float dispRange = min(baseK, 1.0 - baseK);
    float safeDisp = min(dispersionStrength * 0.01 * dispCurve, dispRange);
    float kR = baseK + safeDisp;
    float kG = baseK;
    float kB = baseK - safeDisp;

    half r = layer.sample(center + toCenter * kR).r;
    half g = layer.sample(center + toCenter * kG).g;
    half b = layer.sample(center + toCenter * kB).b;
    half a = layer.sample(center + toCenter * kG).a;

    // Edge highlight ring — 얇은 유리 rim 강조.
    float rim = smoothstep(0.92, 0.96, normalized)
              * (1.0 - smoothstep(0.96, 1.0, normalized));
    half3 highlight = half3(1.0) * rim * edgeHighlight;

    // ── Iridescence (무지개 광택) ─────────────────────────────────────────
    // lens 안쪽에 각도+반경 기반 HSV spectrum 을 합성한다.
    // 배경(흰색 + indigo 텍스트 등)을 그대로 굴절시키면 lens 안쪽이 회녹색 톤으로
    // 단조롭게 보이는데, iridescent overlay 가 비누거품·진주 같은 무지개 광택을
    // 더해 "유리 너머의 빛이 분광되어 보인다" 는 인지를 만든다.
    //
    // 합성 위치 — 중심부터 가장자리까지 전구간에 ring mask 로 fade in/out:
    //   normalized ∈ [0.05, 0.30]  fade in (이전 0.10~0.40 보다 더 넓게 시작)
    //   normalized ∈ [0.75, 0.92]  fade out (이전 0.70~0.90 보다 살짝 외곽까지)
    // → 무지개가 덮이는 lens 내부 영역이 넓어져 "lens 가 통과했다" 인지가 강화된다.
    // 가장자리(0.92+) 는 rim highlight 영역이라 iridescence 와 겹치지 않게 분리.
    float angle = atan2(toCenter.y, toCenter.x);
    float angleNorm = (angle + 3.14159265) / 6.28318530;  // 0~1
    // 무지개 흐름 — time 항이 hue 를 회전시켜 색띠가 유동한다 (time=0 이면 기존과 동일).
    const float hueFlowSpeed = 0.12;  // cycle/s
    float hue = fract(angleNorm + normalized * 0.6 + time * hueFlowSpeed);
    float h6 = hue * 6.0;
    half3 iridescent = half3(
        clamp(abs(h6 - 3.0) - 1.0, 0.0, 1.0),
        clamp(2.0 - abs(h6 - 2.0), 0.0, 1.0),
        clamp(2.0 - abs(h6 - 4.0), 0.0, 1.0)
    );
    float irisMask = smoothstep(0.05, 0.30, normalized)
                   * (1.0 - smoothstep(0.75, 0.92, normalized))
                   * iridescenceStrength;
    // 미세 호흡 — 광택 강도가 부드럽게 맥동. time>0 일 때만 적용해 정적 호출부 회귀를 막는다.
    if (time > 0.0) {
        const float breathSpeed = 2.2;  // rad/s
        irisMask *= (0.85 + 0.15 * sin(time * breathSpeed));
    }
    half3 baseRGB = half3(r, g, b);

    // 채도 조정 — 진주·비누거품 톤을 위해 iridescent 자체를 흰색에 살짝 mix.
    // **0.35 = 흰빛 65% + 원색 35%** (이전 0.55 보다 vivid). 사용자가 "lens 안쪽이
    // 무지개로 물들었다" 를 또렷이 인지하도록 원색 비중을 올림. 그래도 흰빛 65% 비중이
    // 남아 있어 글자가 완전히 뭉개지진 않고 *유리에 비친 무지개* 톤으로 읽힌다.
    half3 pastelIridescent = mix(half3(1.0), iridescent, half(0.35));
    half3 finalRGB = mix(baseRGB, pastelIridescent, half(irisMask));

    // ── 이동 specular glint ───────────────────────────────────────────────
    // 대각 축을 따라 움직이는 가우시안 밝은 띠 — 유리 표면을 빛줄기가 주기적으로
    // 가로지르는 반짝임. time>0 일 때만 (정적/인터랙티브 호출부는 glint 없이 회귀 보존).
    // exp(-d*d) 로 띠를 만든다. pow(음수, 2.0) 이 일부 GPU 에서 NaN 을 내므로 d*d 직접 사용.
    half3 glintHighlight = half3(0.0);
    if (time > 0.0) {
        const float glintSpeed = 0.45;      // sweep/s
        const float glintWidth = 0.18;
        const float glintIntensity = 0.6;
        float s = dot(toCenter, normalize(float2(1.0, 1.0))) / radius;  // 대각 좌표 ≈ [-1,1]
        float sweepPos = -1.3 + fract(time * glintSpeed) * 2.6;         // 한쪽→반대쪽 주기 이동
        float d = (s - sweepPos) / glintWidth;
        float glint = exp(-d * d);                                      // 밝은 띠
        glint *= (1.0 - smoothstep(0.70, 1.0, normalized));            // rim 영역과 분리
        glintHighlight = half3(1.0) * half(glint * glintIntensity);
    }

    return half4(finalRGB + highlight + glintHighlight, a);
}
