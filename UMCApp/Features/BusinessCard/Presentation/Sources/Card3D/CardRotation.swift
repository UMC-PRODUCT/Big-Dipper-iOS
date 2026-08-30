//
//  CardRotation.swift
//  BusinessCardPresentation
//

import CoreGraphics
import Foundation
import simd

/// 3D 명함의 회전 상태 (#1247).
///
/// **SwiftUI 상태가 아니다.** 자이로가 초당 60회 갱신하는 값이라 관측 프로퍼티에 담으면
/// `body` 가 초당 60회 돈다. ``BusinessCard3DScene`` 이 비관측으로 들고 있다가
/// ``quaternion`` 을 엔티티 `transform` 에 직접 기입한다.
///
/// 플립은 각도가 아니라 `Bool` 이다 — 각도로 누적하면 두 번째 플립에서 360° 가 되고
/// 쿼터니언 slerp 가 `dot ≈ -1` 에서 회전축을 못 정해 퇴화한다.
struct CardRotation: Equatable {

    // MARK: - Property

    /// rest 기준 yaw 편차(라디안). 플립 각도는 여기 섞이지 않고 ``quaternion`` 에서만 더해진다.
    var yaw: Float

    /// rest 기준 pitch 편차(라디안).
    var pitch: Float

    /// 뒷면을 보고 있는지. 각도가 아니라 Bool 이라 identity ↔ 180° 사이만 오간다.
    var isFlipped: Bool

    /// 유일한 정본 가독 포즈. 플립·복귀는 항상 여기서 시작하고 여기로 돌아온다.
    static let rest = CardRotation(yaw: 0, pitch: 0, isFlipped: false)

    // MARK: - Computed Property

    /// 손을 뗐을 때의 자세. **뒤집힘은 보존한다** — 놓았다고 앞면으로 튀면 안 된다.
    var released: CardRotation {
        CardRotation(yaw: 0, pitch: 0, isFlipped: isFlipped)
    }

    /// 엔티티 `transform.rotation` 에 넣을 회전.
    ///
    /// 왼쪽 곱은 부모(월드) 공간에 나중에 적용된다. pitch 를 월드 X 축에 두어야
    /// 180° 뒤집힌 상태에서도 「아래로 끌면 위쪽이 눕는다」가 유지된다.
    ///
    /// yaw 는 월드 Y 축이라 뒷면에서는 좌우가 뒤집혀 보인다. **의도한 것이다** —
    /// 손에 든 실물 카드가 그렇게 움직인다. 부호를 뒤집지 않는다.
    var quaternion: simd_quatf {
        let flipAngle: Float = isFlipped ? .pi : 0
        let aroundY = simd_quatf(angle: yaw + flipAngle, axis: [0, 1, 0])
        let aroundX = simd_quatf(angle: pitch, axis: [1, 0, 0])
        return aroundX * aroundY
    }

    // MARK: - Function

    /// 드래그 이동량을 클램프된 각도로 옮긴다.
    ///
    /// `DragGesture` 의 `translation` 은 제스처 시작점 기준 누적값이라 자기 각도에 더하지
    /// 않고 절대 매핑한다 — 더하면 한 번의 드래그가 상한을 몇 바퀴씩 돈다.
    func dragged(by translation: CGSize) -> CardRotation {
        let perPoint = Card3DMetrics.radians(Card3DMetrics.degreesPerPoint)
        return CardRotation(
            yaw: Self.clamped(Float(translation.width) * perPoint, limit: Card3DMetrics.yawLimit),
            pitch: Self.clamped(
                Float(translation.height) * perPoint,
                limit: Card3DMetrics.pitchLimit
            ),
            isFlipped: isFlipped
        )
    }

    /// 자이로 상대 자세를 클램프된 각도로 옮긴다. 게인은 1.0 — 기기를 30° 기울이면 카드도
    /// 30° 기운다(클램프에 걸릴 때까지). 「유리 뒤에 카드가 놓여 있다」는 은유가 그대로 성립한다.
    ///
    /// 부호: 기기 오른쪽 모서리가 뒤로 넘어가면(roll > 0) 사용자는 카드를 오른쪽에서 보게
    /// 되므로 카드의 오른쪽 모서리가 앞으로 나와야 한다 → yaw 는 roll 의 반대 부호다.
    /// pitch 는 같은 유도로 부호가 유지된다. **실기기에서 확인할 항목이다.**
    func rotated(roll: Double, pitch: Double) -> CardRotation {
        CardRotation(
            yaw: Self.clamped(Float(-roll), limit: Card3DMetrics.yawLimit),
            pitch: Self.clamped(Float(pitch), limit: Card3DMetrics.pitchLimit),
            isFlipped: isFlipped
        )
    }

    /// 센서 노이즈용 지수 평활. `factor` 가 1 이면 목표를 그대로 따르고 0 이면 멈춘다.
    func blended(toward target: CardRotation, factor: Float) -> CardRotation {
        CardRotation(
            yaw: yaw + (target.yaw - yaw) * factor,
            pitch: pitch + (target.pitch - pitch) * factor,
            isFlipped: target.isFlipped
        )
    }

    /// 플립 목표 자세. **항상 rest 기울기에서 시작한다** — 기울어진 채로 뒤집히면
    /// 어느 면이 보이는 중인지 읽기 어렵다.
    func flipped(_ isFlipped: Bool) -> CardRotation {
        CardRotation(yaw: 0, pitch: 0, isFlipped: isFlipped)
    }

    // MARK: - Private

    /// 양쪽 대칭 클램프. `abs` 로 자르면 한쪽 방향만 상한에 걸린다.
    private static func clamped(_ value: Float, limit: Float) -> Float {
        min(max(value, -limit), limit)
    }
}
