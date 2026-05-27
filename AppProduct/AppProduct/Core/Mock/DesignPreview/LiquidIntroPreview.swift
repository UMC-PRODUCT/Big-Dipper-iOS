import SwiftUI

// 영상에서 본 메타볼 + 손가락 따라가기 인터랙션 데모.
//
// 작동 방식
// 1. 흰색 원들을 Canvas 에 그린다.
// 2. blur 로 가장자리를 번지게 만든 뒤 alphaThreshold 로 다시 또렷하게 자르면
//    가까운 원들이 한 덩어리로 융합된다 (메타볼 트릭).
// 3. 손가락 위치에도 큰 원을 그려넣어 주변 원들과 시각적으로 묶이게 한다.
// 4. 각 원의 home 좌표를 시간 함수로 흔들면 평상시에는 둥둥 떠다닌다.
// 5. 손가락이 있으면 거리 기반 보간으로 원들이 그쪽으로 끌려간다.
struct LiquidIntroPreview: View {

    // MARK: - Property

    @State private var balls: [LiquidBall] = LiquidBall.makeDefault()
    @State private var touch: CGPoint?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                blobLayer(in: geo.size)
                    .ignoresSafeArea()

                overlayHint
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { touch = $0.location }
                    .onEnded { _ in
                        withAnimation(.spring(duration: 0.6)) {
                            touch = nil
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Subview

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.86, blue: 0.95),
                Color(red: 0.95, green: 0.85, blue: 1.00),
                Color(red: 0.88, green: 0.90, blue: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func blobLayer(in size: CGSize) -> some View {
        // 메타볼 모양 안에 보라/파랑 그라데이션이 채워지도록
        // Canvas 결과를 mask 로 사용.
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.18, blue: 0.85),
                Color(red: 0.22, green: 0.42, blue: 0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, _ in
                    // 필터 적용 순서: 추가 역순으로 적용된다.
                    // 따라서 아래 코드는 "blur 먼저 → alphaThreshold 다음" 으로 동작.
                    context.addFilter(.alphaThreshold(min: 0.42, color: .white))
                    context.addFilter(.blur(radius: 48))
                    context.drawLayer { layer in
                        for ball in balls {
                            let center = ball.position(
                                at: time,
                                in: size,
                                attractor: touch
                            )
                            draw(circle: layer, at: center, radius: ball.radius)
                        }
                        if let touch {
                            draw(circle: layer, at: touch, radius: 80)
                        }
                    }
                }
            }
        }
    }

    private var overlayHint: some View {
        VStack {
            Spacer()
            Text("화면을 누른 채 드래그해 보세요")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 40)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Function

    private func draw(circle layer: GraphicsContext, at point: CGPoint, radius: CGFloat) {
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        layer.fill(Circle().path(in: rect), with: .color(.white))
    }
}

// MARK: - Model

/// 메타볼 데모의 떠다니는 원 한 개.
///
/// - `homeOffset` 은 화면 크기에 대한 0~1 비율 좌표라 디바이스 크기가 달라져도 레이아웃이 깨지지 않는다.
/// - `drift` 는 시간 함수로 만드는 흔들림 진폭/속도/위상.
/// - `attractionStrength` 는 손가락에 끌리는 정도 (0~1). 1 이면 손가락 위로 완전히 흡수.
private struct LiquidBall {
    let homeOffsetX: CGFloat
    let homeOffsetY: CGFloat
    let radius: CGFloat
    let driftRadius: CGFloat
    let driftSpeed: Double
    let phase: Double
    let attractionStrength: CGFloat

    /// 현재 시각·화면 크기·손가락 위치를 받아 이 원의 그려질 좌표를 계산.
    func position(
        at time: TimeInterval,
        in size: CGSize,
        attractor: CGPoint?
    ) -> CGPoint {
        let baseX = homeOffsetX * size.width
        let baseY = homeOffsetY * size.height

        // 1) home 좌표를 시간 함수로 흔들기 (drift).
        let driftX = baseX + cos(time * driftSpeed + phase) * driftRadius
        let driftY = baseY + sin(time * driftSpeed * 0.8 + phase * 1.3) * driftRadius
        let drifted = CGPoint(x: driftX, y: driftY)

        // 2) 손가락이 있으면 거리 기반 falloff 로 그쪽으로 보간.
        guard let attractor else { return drifted }
        let dx = attractor.x - drifted.x
        let dy = attractor.y - drifted.y
        let distance = sqrt(dx * dx + dy * dy)
        let influenceRadius: CGFloat = 280
        let falloff = max(0, 1 - distance / influenceRadius)
        let pull = falloff * attractionStrength
        return CGPoint(x: drifted.x + dx * pull, y: drifted.y + dy * pull)
    }

    static func makeDefault() -> [LiquidBall] {
        [
            // 중앙 응집 (큰 메인 덩어리 — 항상 한 덩어리로 보이는 코어).
            LiquidBall(homeOffsetX: 0.46, homeOffsetY: 0.48, radius: 78, driftRadius: 12, driftSpeed: 0.45, phase: 0.0, attractionStrength: 0.55),
            LiquidBall(homeOffsetX: 0.54, homeOffsetY: 0.46, radius: 72, driftRadius: 14, driftSpeed: 0.40, phase: 1.7, attractionStrength: 0.55),
            LiquidBall(homeOffsetX: 0.50, homeOffsetY: 0.58, radius: 68, driftRadius: 16, driftSpeed: 0.50, phase: 2.4, attractionStrength: 0.60),
            LiquidBall(homeOffsetX: 0.42, homeOffsetY: 0.60, radius: 58, driftRadius: 18, driftSpeed: 0.55, phase: 0.9, attractionStrength: 0.65),
            LiquidBall(homeOffsetX: 0.58, homeOffsetY: 0.62, radius: 54, driftRadius: 20, driftSpeed: 0.50, phase: 1.2, attractionStrength: 0.65),

            // 중간 거리 (코어와 가끔 합쳐졌다 떨어지는 유동층).
            LiquidBall(homeOffsetX: 0.30, homeOffsetY: 0.42, radius: 46, driftRadius: 28, driftSpeed: 0.55, phase: 2.1, attractionStrength: 0.75),
            LiquidBall(homeOffsetX: 0.70, homeOffsetY: 0.40, radius: 46, driftRadius: 28, driftSpeed: 0.60, phase: 0.5, attractionStrength: 0.75),
            LiquidBall(homeOffsetX: 0.34, homeOffsetY: 0.70, radius: 42, driftRadius: 30, driftSpeed: 0.50, phase: 1.8, attractionStrength: 0.80),
            LiquidBall(homeOffsetX: 0.66, homeOffsetY: 0.72, radius: 42, driftRadius: 30, driftSpeed: 0.55, phase: 2.6, attractionStrength: 0.80),

            // 외곽 위성 (작고 큰 진폭으로 움직이며 자연스러운 흐름 연출).
            LiquidBall(homeOffsetX: 0.18, homeOffsetY: 0.30, radius: 30, driftRadius: 42, driftSpeed: 0.70, phase: 0.3, attractionStrength: 0.90),
            LiquidBall(homeOffsetX: 0.82, homeOffsetY: 0.30, radius: 30, driftRadius: 42, driftSpeed: 0.65, phase: 2.9, attractionStrength: 0.90),
            LiquidBall(homeOffsetX: 0.20, homeOffsetY: 0.80, radius: 28, driftRadius: 44, driftSpeed: 0.60, phase: 1.4, attractionStrength: 0.95),
            LiquidBall(homeOffsetX: 0.80, homeOffsetY: 0.80, radius: 28, driftRadius: 44, driftSpeed: 0.65, phase: 0.7, attractionStrength: 0.95),
            LiquidBall(homeOffsetX: 0.50, homeOffsetY: 0.18, radius: 26, driftRadius: 38, driftSpeed: 0.55, phase: 2.2, attractionStrength: 0.95)
        ]
    }
}

// MARK: - Preview

#Preview {
    LiquidIntroPreview()
}
