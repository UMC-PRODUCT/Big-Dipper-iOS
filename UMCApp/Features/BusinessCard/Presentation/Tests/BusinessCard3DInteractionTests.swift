//
//  BusinessCard3DInteractionTests.swift
//  BusinessCardPresentationTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
import simd
@testable import BusinessCardPresentation

/// 3D 명함(#1247)의 회전 기하와 인터랙션 판정을 잠그는 테스트.
///
/// 전부 순수 값 타입 단정이라 RealityKit 씬 없이 돈다. `BusinessCard3DScene`·
/// `BusinessCard3DView` 는 여기서 보지 않는다 — 씬 그래프와 SwiftUI 뷰라 테스트가
/// 값보다 비싸고, 그쪽 회귀는 실기기 체크리스트가 잡는다.
///
/// 실행: `cd UMCApp && make test SCHEME=BusinessCardPresentation`
@Suite("BusinessCard3D — 회전 기하·인터랙션 정책")
struct BusinessCard3DInteractionTests {

    // MARK: - 드래그 → 각도

    @Test("가로로 멀리 끌어도 yaw 가 상한에서 멈춘다")
    func dragClampsYawAtUpperLimit() {
        let rotation = CardRotation.rest.dragged(by: CGSize(width: 1_000, height: 0))

        #expect(rotation.yaw == Card3DMetrics.yawLimit)
    }

    @Test("세로로 멀리 끌어도 pitch 가 상한에서 멈춘다")
    func dragClampsPitchAtUpperLimit() {
        let rotation = CardRotation.rest.dragged(by: CGSize(width: 0, height: 1_000))

        #expect(rotation.pitch == Card3DMetrics.pitchLimit)
    }

    @Test("반대 방향 드래그는 하한에서 멈춘다")
    func dragClampsAtLowerLimit() {
        // `abs` 로 클램프하면 한쪽 방향만 걸리고 반대쪽은 카드가 몇 바퀴 돈다.
        let rotation = CardRotation.rest.dragged(by: CGSize(width: -1_000, height: -1_000))

        #expect(rotation.yaw == -Card3DMetrics.yawLimit)
        #expect(rotation.pitch == -Card3DMetrics.pitchLimit)
    }

    @Test("상한 안에서는 이동량에 선형 비례한다")
    func dragMapsLinearlyBelowLimit() {
        let rotation = CardRotation.rest.dragged(by: CGSize(width: 40, height: 40))

        #expect(isClose(rotation.yaw, Card3DMetrics.radians(10)))
        #expect(isClose(rotation.pitch, Card3DMetrics.radians(10)))
    }

    // MARK: - 플립

    @Test("플립을 왕복해도 각도가 누적되지 않는다")
    func flipRoundTripDoesNotAccumulate() {
        // 각도로 누적하면 두 번째 플립에서 360° 가 되고 slerp 가 퇴화한다.
        let roundTrip = CardRotation.rest.flipped(true).flipped(false)

        #expect(roundTrip == .rest)
        #expect(isClose(roundTrip.quaternion.angle, CardRotation.rest.quaternion.angle))
    }

    @Test("뒤집힌 자세는 Y 축 180° 다")
    func flippedRotatesHalfTurnAroundVerticalAxis() {
        let quaternion = CardRotation.rest.flipped(true).quaternion

        #expect(isClose(quaternion.angle, .pi))
        #expect(isClose(abs(quaternion.axis.y), 1))
        #expect(isClose(quaternion.axis.x, 0))
        #expect(isClose(quaternion.axis.z, 0))
    }

    @Test("뒷면에서도 pitch 가 같은 방향으로 눕는다")
    func pitchKeepsWorldAxisWhenFlipped() {
        // pitch 를 월드 X 로 두지 않으면(합성 순서가 뒤집히면) 뒷면에서 위아래가 반대로 돈다.
        let pitch = Card3DMetrics.radians(15)
        let front = CardRotation(yaw: 0, pitch: pitch, isFlipped: false)
        let back = CardRotation(yaw: 0, pitch: pitch, isFlipped: true)

        // 카드의 위쪽 방향은 Y 축 회전에 영향을 받지 않으므로 앞뒤가 같아야 한다.
        let frontUp = front.quaternion.act(SIMD3<Float>(0, 1, 0))
        let backUp = back.quaternion.act(SIMD3<Float>(0, 1, 0))

        #expect(isClose(frontUp.y, backUp.y))
        #expect(isClose(frontUp.z, backUp.z))
        // 위쪽이 화면 앞으로 나온다 = 아래로 끌면 위가 눕는다.
        #expect(frontUp.z > 0)
    }

    // MARK: - 자이로

    @Test("자이로 입력도 같은 상한에서 멈춘다")
    func gyroInputSharesClamp() {
        // 드래그와 다른 경로라 클램프가 빠지기 쉽다.
        let tilted = CardRotation.rest.rotated(roll: 2.0, pitch: 2.0)
        let opposite = CardRotation.rest.rotated(roll: -2.0, pitch: -2.0)

        #expect(abs(tilted.yaw) == Card3DMetrics.yawLimit)
        #expect(abs(tilted.pitch) == Card3DMetrics.pitchLimit)
        #expect(tilted.yaw == -opposite.yaw)
        #expect(tilted.pitch == -opposite.pitch)
    }

    @Test("평활이 목표로 단조 수렴한다")
    func blendingConvergesTowardTarget() {
        let target = CardRotation(
            yaw: Card3DMetrics.yawLimit,
            pitch: Card3DMetrics.pitchLimit,
            isFlipped: false
        )
        var current = CardRotation.rest
        var previousDistance = Float.greatestFiniteMagnitude

        for _ in 0..<30 {
            current = current.blended(toward: target, factor: Card3DMetrics.motionSmoothing)
            let distance = abs(target.yaw - current.yaw)
            #expect(distance < previousDistance)
            previousDistance = distance
        }

        #expect(isClose(current.yaw, target.yaw, tolerance: 1e-2))
        #expect(isClose(current.pitch, target.pitch, tolerance: 1e-2))
    }

    @Test("손을 떼도 뒤집힘은 유지된다")
    func releaseKeepsFlippedFace() {
        let released = CardRotation(
            yaw: Card3DMetrics.yawLimit,
            pitch: Card3DMetrics.pitchLimit,
            isFlipped: true
        ).released

        #expect(released == CardRotation(yaw: 0, pitch: 0, isFlipped: true))
    }

    // MARK: - 접근성 정책

    @Test("Reduce Motion 이면 플립이 즉시 끝난다")
    func reduceMotionMakesFlipInstant() {
        #expect(CardInteractionPolicy.flipDuration(reduceMotion: true) == 0)
        #expect(CardInteractionPolicy.flipDuration(reduceMotion: false) > 0)
    }

    @Test("Reduce Motion 이면 토글이 켜져 있어도 자이로가 돌지 않는다")
    func reduceMotionStopsGyro() {
        #expect(makeGyroDecision(reduceMotion: true) == false)
        #expect(makeGyroDecision() == true)
    }

    @Test("VoiceOver·백그라운드·하드웨어 부재는 각각 자이로를 멈춘다")
    func gyroStopsOnVoiceOverBackgroundAndMissingHardware() {
        #expect(makeGyroDecision(isVoiceOverRunning: true) == false)
        #expect(makeGyroDecision(scenePhase: .background) == false)
        #expect(makeGyroDecision(scenePhase: .inactive) == false)
        #expect(makeGyroDecision(isHardwareAvailable: false) == false)
        #expect(makeGyroDecision(isEnabled: false) == false)
    }

    @Test("접근성 글자 크기·로딩·실패는 2D 로 간다")
    func fallsBackToTwoDimensionalCard() {
        #expect(
            CardInteractionPolicy.renderMode(phase: .ready, dynamicTypeSize: .accessibility1)
                == .twoDimensional
        )
        #expect(
            CardInteractionPolicy.renderMode(phase: .loading, dynamicTypeSize: .large)
                == .twoDimensional
        )
        #expect(
            CardInteractionPolicy.renderMode(phase: .failed, dynamicTypeSize: .large)
                == .twoDimensional
        )
        #expect(
            CardInteractionPolicy.renderMode(phase: .ready, dynamicTypeSize: .large)
                == .threeDimensional
        )
    }

    // MARK: - Private

    /// 기본값이 전부 「돌아야 하는」 조합이라 각 테스트가 끄고 싶은 조건 하나만 넘긴다.
    private func makeGyroDecision(
        isEnabled: Bool = true,
        reduceMotion: Bool = false,
        isVoiceOverRunning: Bool = false,
        scenePhase: ScenePhase = .active,
        isHardwareAvailable: Bool = true
    ) -> Bool {
        CardInteractionPolicy.shouldRunGyro(
            isEnabled: isEnabled,
            reduceMotion: reduceMotion,
            isVoiceOverRunning: isVoiceOverRunning,
            scenePhase: scenePhase,
            isHardwareAvailable: isHardwareAvailable
        )
    }

    /// 라디안 비교용. 도 → 라디안 변환이 끼어 있어 정확한 동등 비교가 성립하지 않는다.
    private func isClose(_ lhs: Float, _ rhs: Float, tolerance: Float = 1e-5) -> Bool {
        abs(lhs - rhs) < tolerance
    }
}
