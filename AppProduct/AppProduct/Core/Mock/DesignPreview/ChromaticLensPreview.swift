//
//  ChromaticLensPreview.swift
//  AppProduct
//
//  Apple `.glassEffect(.clear.interactive(), in: ...)` 가 노출하지 않는 굴절·색분산 강도를
//  직접 만지기 위한 Metal shader 기반 PoC.
//
//  ZStack 의 모든 콘텐츠 위에 `.layerEffect` 로 chromaticLens 셰이더를 적용한다.
//  슬라이더로 refraction / dispersion / edge highlight / radius 를 실시간 조정 가능 —
//  Apple 빌트인이 안 노출하는 knob 들이다.
//
//  Production `WabiSplashView` 와의 차이
//  - Apple Liquid Glass 는 시스템 광원·반사 등 추가 chrome 이 자동 포함되지만 강도 조정 불가.
//  - 이 셰이더는 chrome 이 단순(rim ring 만)하나 모든 수치를 디자이너가 직접 조정 가능.
//  - 실제 production 으로 옮기려면 .clear.interactive() 대신 이 셰이더를 쓰거나, 둘을 합성해야 함.
//

import SwiftUI

struct ChromaticLensPreview: View {

    // MARK: - Property

    @State private var center: CGPoint = .init(x: 200, y: 400)
    @State private var refractionStrength: Double = 45
    @State private var dispersionStrength: Double = 14
    @State private var edgeHighlight: Double = 0.5
    @State private var radius: Double = 150

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            lensCanvas
            controls
        }
    }

    // MARK: - Subview

    private var lensCanvas: some View {
        GeometryReader { geo in
            ZStack {
                background

                VStack(spacing: 24) {
                    Text("Meet Wabi.")
                        .font(.system(size: 56, weight: .bold))
                    Text("A new era of\nsoftware is here.")
                        .font(.system(size: 26, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .foregroundStyle(.white)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { center = $0.location }
            )
            .layerEffect(
                ShaderLibrary.chromaticLens(
                    .float2(Float(center.x), Float(center.y)),
                    .float(Float(radius)),
                    .float(Float(refractionStrength)),
                    .float(Float(dispersionStrength)),
                    .float(Float(edgeHighlight))
                ),
                maxSampleOffset: CGSize(width: radius, height: radius)
            )
            .onAppear {
                center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.16),
                Color(red: 0.18, green: 0.10, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            slider("Refraction",     value: $refractionStrength,  range: 0...100)
            slider("Dispersion",     value: $dispersionStrength,  range: 0...30)
            slider("Edge highlight", value: $edgeHighlight,       range: 0...1.5)
            slider("Radius",         value: $radius,              range: 50...260)

            Text("화면을 드래그하면 lens 중심이 이동합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func slider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

// MARK: - Preview

#Preview {
    ChromaticLensPreview()
}
