//
//  BusinessCard3DScene.swift
//  BusinessCardPresentation
//

import BusinessCardDomain
import CoreGraphics
import CoreMotion
import Foundation
import RealityKit
import SwiftUI

/// 3D 명함의 RealityKit 씬 핸들 (#1247).
///
/// **의도적으로 `@Observable` 이 아니다.** 자이로가 초당 60회 회전을 갱신하는데 관측
/// 프로퍼티에 쓰면 `body` 가 초당 60회 돈다. 회전은 SwiftUI 상태가 아니라 엔티티
/// `transform` 에 직접 기입한다 — `Entity` 는 참조 타입이고 SwiftUI 가 관측하지 않으므로
/// 아무리 자주 써도 `body` 는 돌지 않는다. 같은 이유로 `RealityView` 의 `update:` 도 쓰지
/// 않는다(상태가 바뀔 때마다 호출되므로 결국 같은 비용이다).
///
/// 핵심 규칙 #1(`@Observable` 강제)이 막으려는 것은 Combine 시대의 관측 래퍼
/// (`@StateObject`/`@ObservedObject`/`@Published`)다. 이 타입은 셋 중 어느 것도 아니고
/// 뷰 상태를 들고 있는 ViewModel 도 아니다 — 씬 그래프의 핸들이다.
@MainActor
final class BusinessCard3DScene {

    // MARK: - Property

    /// 현재 회전. 자이로 평활이 이전 값을 읽어야 해서 들고 있는다.
    private(set) var rotation: CardRotation = .rest

    private var cardEntity: Entity?

    /// 진행 중인 복귀·플립 애니메이션. 직접 기입 전에 반드시 세워야 한다 —
    /// 안 그러면 애니메이션이 기입한 transform 을 계속 덮어쓴다.
    private var activeAnimation: AnimationPlaybackController?

    private var isDragging = false

    /// Apple 문서는 `CMMotionManager` 를 앱당 하나만 만들라고 하지만 **씬마다 하나씩** 둔다.
    /// 마이페이지 히어로와 명함 상세가 `NavigationStack` 으로 이어져 있는데 push 시 새 뷰의
    /// `onAppear` 가 이전 뷰의 `onDisappear` 보다 먼저 도는 경우가 있다. 공유 인스턴스라면
    /// 떠나는 화면의 `stop` 이 새 화면의 업데이트를 죽여 「가끔 자이로가 안 먹는」 재현 불가
    /// 버그가 된다. 정지 상태의 매니저는 비용이 0 이고 동시에 **실행**되는 것은 항상 하나다.
    private let motionManager = CMMotionManager()

    /// 자이로를 켠 시점의 자세. 절대 자세를 그대로 쓰면 켠 순간 카드가 최대치로 기울어 있다.
    private var referenceAttitude: CMAttitude?

    var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    // MARK: - Init

    /// SwiftUI 가 `@State` 기본값을 nonisolated 문맥에서 만든다. 저장 프로퍼티 기본값이
    /// 전부 갓 만든 값이라 격리가 필요 없다.
    nonisolated init() {}

    // MARK: - Function

    /// 카드 엔티티를 만들어 든다.
    ///
    /// **초기 자세는 여기서 세우지 않는다.** 로드는 await 를 건너 몇 초가 걸릴 수 있고
    /// 그동안 2D 폴백이 이미 조작 가능하다 — 로드 시작 시점의 `isFlipped` 를 여기서 쓰면
    /// 로드 중에 사용자가 누른 플립이 완료 직후 되돌아간다. 자세는 뷰가 `.ready` 로
    /// 넘어가는 순간 최신 값으로 세운다(``BusinessCard3DView`` 의 `onChange(of: phase)`).
    func load(
        card: MyCard,
        makeEntity: @MainActor (MyCard) async throws -> Entity
    ) async throws {
        cardEntity = try await makeEntity(card)
    }

    /// `RealityView` 의 `make:` 에서 한 번 부른다.
    func attach(to content: inout RealityViewCameraContent) {
        content.camera = .virtual
        // 템플릿 머티리얼이 UsdPreviewSurface(PBR) 라 광원 없이는 카드가 검게 나온다.
        content.environment = .default

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = Card3DMetrics.fieldOfView
        camera.position = [0, 0, Card3DMetrics.cameraDistance]
        content.add(camera)

        // 환경광만으로 충분한지는 실기기에서 눈으로 봐야 알 수 있는데, 검은 카드가 배포되는
        // 쪽이 사고가 크므로 키 라이트를 같이 넣고 시작한다. 기울일 때 표면을 훑는 스페큘러가
        // 드래그·자이로를 할 값어치의 절반이라 `UnlitMaterial` 로 우회하지 않는다.
        let keyLight = DirectionalLight()
        keyLight.light.intensity = Card3DMetrics.keyLightIntensity
        keyLight.look(at: .zero, from: Card3DMetrics.keyLightPosition, relativeTo: nil)
        content.add(keyLight)

        guard let cardEntity else { return }
        cardEntity.transform.rotation = rotation.quaternion
        content.add(cardEntity)
    }

    /// 회전을 반영한다. `duration` 이 0 이면 애니메이션 없이 직접 기입한다.
    func setRotation(
        _ rotation: CardRotation,
        duration: TimeInterval,
        timing: AnimationTimingFunction = .easeOut
    ) {
        activeAnimation?.stop()
        activeAnimation = nil
        self.rotation = rotation

        guard let cardEntity else { return }
        guard duration > 0 else {
            cardEntity.transform.rotation = rotation.quaternion
            return
        }

        var target = cardEntity.transform
        target.rotation = rotation.quaternion
        activeAnimation = cardEntity.move(
            to: target,
            relativeTo: cardEntity.parent,
            duration: duration,
            timingFunction: timing
        )
    }

    /// 드래그 중. `translation` 은 제스처 시작점 기준 누적값이다.
    func drag(by translation: CGSize) {
        isDragging = true
        // 드래그를 시작하면 자이로 기준 자세를 버린다 — 손을 뗀 뒤 옛 기준으로 계산하면
        // 카드가 한 번 튄다.
        referenceAttitude = nil
        setRotation(rotation.dragged(by: translation), duration: 0)
    }

    /// 손을 뗐을 때. rest 로 감속 복귀한다 — 관성은 클램프에 부딪혀 「버그처럼」 멈추고,
    /// 스프링은 RealityKit 타이밍 함수에 대응물이 없다.
    func endDrag() {
        isDragging = false
        referenceAttitude = nil
        setRotation(rotation.released, duration: Card3DMetrics.returnDuration)
    }

    /// 플립. 복귀는 감속만(`easeOut`), 플립은 가속-감속(`easeInOut`) — 두 모션이 눈으로
    /// 구분돼야 어느 쪽이 일어난 건지 읽힌다.
    func setFlipped(_ isFlipped: Bool, duration: TimeInterval) {
        setRotation(rotation.flipped(isFlipped), duration: duration, timing: .easeInOut)
    }

    /// 자이로 구동 여부. 켜고 끌 조건 판정은 ``CardInteractionPolicy`` 의 `shouldRunGyro`
    /// 가 하고 여기서는 시키는 대로만 한다.
    ///
    /// 끄기를 놓쳐도 `CMMotionManager` 가 해제되는 순간 업데이트는 멈춘다 — 씬마다 매니저를
    /// 따로 두는 이유(위 `motionManager` 주석)가 여기서 안전망 역할까지 겸한다.
    func setMotionActive(_ isActive: Bool) {
        guard isActive else {
            motionManager.stopDeviceMotionUpdates()
            referenceAttitude = nil
            return
        }
        guard motionManager.isDeviceMotionAvailable,
              !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = Card3DMetrics.motionInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            // `to: .main` 이 메인 스레드 실행을 보장하므로 assumeIsolated 가 안전하다.
            // 백그라운드 큐를 쓰면 여기서 크래시한다 — 큐를 바꾸지 말 것.
            // 비-Sendable 인 CMDeviceMotion 은 여기서 Double 두 개로 소진되고 밖으로 안 나간다.
            MainActor.assumeIsolated {
                self?.applyMotion(motion.attitude)
            }
        }
    }

    // MARK: - Private

    private func applyMotion(_ attitude: CMAttitude) {
        guard !isDragging else { return }
        // 복귀·플립 애니메이션이 도는 동안은 비켜선다. 직접 기입이 애니메이션을 세우므로
        // 그냥 두면 0.3s 감쇠가 한 프레임 만에 끊긴다.
        guard activeAnimation?.isPlaying != true else { return }

        guard let referenceAttitude else {
            self.referenceAttitude = attitude.copy() as? CMAttitude
            return
        }
        guard let relative = attitude.copy() as? CMAttitude else { return }
        relative.multiply(byInverseOf: referenceAttitude)

        let target = rotation.rotated(roll: relative.roll, pitch: relative.pitch)
        setRotation(
            rotation.blended(toward: target, factor: Card3DMetrics.motionSmoothing),
            duration: 0
        )
    }
}
