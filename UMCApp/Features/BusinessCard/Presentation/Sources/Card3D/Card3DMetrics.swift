//
//  Card3DMetrics.swift
//  BusinessCardPresentation
//

import CoreGraphics
import Foundation
import simd

/// 3D 명함(#1247)의 인터랙션·렌더 수치. **실기기에서 조정할 보정 손잡이**이지 성역이 아니다.
///
/// 설계는 이 값들을 `BusinessCard3DView` 안의 `fileprivate enum Metrics` 로 두려 했지만,
/// 클램프 상수는 ``CardRotation`` 과 인터랙션 테스트가 같이 읽어야 해서 파일 밖으로 나와야
/// 했다. 세 파일에 흩어 놓는 대신 internal 로 한곳에 모은다 — 튜닝하러 열어 볼 파일이
/// 하나여야 값이 서로 어긋나지 않는다.
enum Card3DMetrics {

    // MARK: - Rotation

    /// yaw 상한(라디안, 30°). 전경축소 `cos 30° = 0.866` → 가로 13.4% 압축.
    /// 40°(`cos = 0.766`, 23%)를 텍스트 가독성 상한으로 잡고 여유를 둔 값이다.
    static let yawLimit = radians(30)

    /// pitch 상한(라디안, 20°). `cos 20° = 0.940` → 세로 6% 압축.
    /// yaw 보다 작은 이유: 50mm 세로 안에 이름·학교·칩 3단이 쌓여 행간 여유가 가로보다 적다.
    static let pitchLimit = radians(20)

    /// 드래그 1pt 당 회전량(도). 120pt 드래그에서 yaw 가 상한에 닿는다 —
    /// 120pt 는 히어로 카드 폭(≈365pt)의 1/3 로 편한 엄지 스와이프 1회 분량이다.
    /// pitch 는 같은 배율이라 80pt 에서 상한에 닿는다.
    static let degreesPerPoint: Float = 0.25

    // MARK: - Timing

    /// 손을 뗐을 때 rest 로 돌아오는 시간. 0.25s 미만은 「툭 끊김」, 0.5s 초과는 지연으로
    /// 읽힌다 (UIKit 기본 애니메이션 0.25~0.35 대역).
    static let returnDuration: TimeInterval = 0.3

    /// 플립 시간. 180° 는 복귀(30°)의 6배 이동인데 1.5배만 준다 — 각속도 지각이 선형이
    /// 아니라 6배를 그대로 주면 늘어지게 느껴진다.
    static let flipDuration: TimeInterval = 0.45

    // MARK: - Motion

    /// 자이로 콜백 주기. 디스플레이 주사율에 정렬한다. 1/30 은 배터리 절약안이고
    /// 실기기 측정 후에 판단한다.
    static let motionInterval: TimeInterval = 1.0 / 60.0

    /// 자이로 지수 평활 계수. 정지 상태의 센서 노이즈가 그대로 반영되면 카드가 미세하게
    /// 떤다. 실측 후 조정 대상이다.
    static let motionSmoothing: Float = 0.15

    // MARK: - Render

    /// 카메라 거리(m). `d = h / (2·tan(fov/2)·fill)` = `0.05 / (2 · tan 15° · 0.85)` = 0.109.
    /// fill 0.85 인 이유: pitch 20° 에서 근접 모서리가 8% 커지므로 여유를 둔다.
    static let cameraDistance: Float = 0.11

    /// 시야각(도). 좁을수록 원근 왜곡이 줄어 카드가 「판」으로 읽힌다 (스파이크 값 승계).
    static let fieldOfView: Float = 30

    /// 키 라이트 밝기(lux). **실기기 육안 튜닝 대상.**
    ///
    /// 템플릿 머티리얼이 `UsdPreviewSurface`(PBR) 라 광원이 없으면 카드가 검게 나온다.
    /// `RealityViewEnvironment.default` 의 IBL 만으로 충분한지는 눈으로 봐야 알 수 있는데,
    /// 검은 카드가 배포되는 쪽이 사고가 크므로 키 라이트를 같이 넣고 시작한다.
    /// 너무 밝아 하이라이트가 타면 이 값을 먼저 내린다.
    static let keyLightIntensity: Float = 1_500

    /// 키 라이트 위치(m). 카드 원점을 향해 우상단 앞에서 비춘다 — 기울일 때 표면을 훑는
    /// 스페큘러가 3D 임을 읽히게 하는 요소라 정면 광원으로 두지 않는다.
    /// **실기기 육안 튜닝 대상.**
    static let keyLightPosition: SIMD3<Float> = [0.06, 0.08, 0.15]

    // MARK: - Layout

    /// 3D 표면 종횡비(1.8). 2D 카드의 시안 종횡비(372/205 = 1.815)와 0.8% 차이라
    /// 2D ↔ 3D 교체 시 레이아웃 점프가 눈에 띄지 않는다.
    static let cardAspectRatio = CGFloat(
        BusinessCardTemplate.Geometry.width / BusinessCardTemplate.Geometry.height
    )

    /// 카드 표면과 액션 행 사이. 2D 카드의 `blockSpacing` 과 같은 값이라 두 경로의
    /// 세로 리듬이 어긋나지 않는다.
    static let blockSpacing: CGFloat = 24

    /// 컨트롤 버튼 사이 간격. 버튼 자체의 지름·아이콘 크기는 2D 카드와 공용인
    /// ``CardGlassCircleButton`` 이 들고 있다.
    static let controlSpacing: CGFloat = 8

    /// 컨트롤 오버레이 여백. 2D 카드의 `cardPadding` 과 같은 값이라 두 경로에서 버튼이
    /// 같은 자리에 보인다.
    static let controlMargin: CGFloat = 16

    /// 액션 버튼 사이 간격. 2D 카드의 `buttonSpacing` 승계.
    static let actionSpacing: CGFloat = 10

    /// 2D 폴백 ↔ 3D 교체 크로스페이드. 카드 높이와 액션 버튼 모양이 같이 바뀌는
    /// 전환이라 하드컷이면 화면이 다시 그려진 것처럼 읽힌다.
    static let crossfadeDuration: TimeInterval = 0.25

    // MARK: - Function

    /// 도 → 라디안. 상수를 도(度)로 적고 여기서 한 번만 바꾼다 — 코드에 `0.5236` 같은
    /// 값이 흩어지면 설계 표와 대조가 불가능해진다.
    static func radians(_ degrees: Float) -> Float {
        degrees * .pi / 180
    }
}
