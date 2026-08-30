//
//  CardInteractionPolicy.swift
//  BusinessCardPresentation
//

import Foundation
import SwiftUI

/// 3D 씬 준비 상태.
///
/// `Loadable` 을 쓰지 않는다 — `Loadable` 은 `Equatable` 값을 요구하는데 `Entity` 는
/// `Equatable` 이 아니고, 애초에 엔티티를 SwiftUI 상태에 담는 것 자체가 초당 60회
/// `body` 재평가로 가는 길이다.
enum CardScenePhase: Equatable {
    case loading
    case ready
    case failed
}

/// 카드를 어떤 방식으로 그릴지.
enum CardRenderMode: Equatable {
    case twoDimensional
    case threeDimensional
}

/// 3D 명함의 인터랙션 판정. 전부 순수 함수라 시뮬레이터에서 RealityKit 없이 테스트된다.
enum CardInteractionPolicy {

    // MARK: - Function

    /// 플립 애니메이션 길이. Reduce Motion 이면 0 — 즉시 전환한다.
    ///
    /// 드래그와 그 복귀는 여기서 다루지 않는다. Reduce Motion 이 막는 것은 사용자가 만들지
    /// 않은 자율 모션이고, 드래그는 손가락이 직접 만드는 1:1 조작이다.
    static func flipDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : Card3DMetrics.flipDuration
    }

    /// 자이로 센서를 돌릴지. **어느 하나라도 막으면 false** — 토글이 켜져 있어도
    /// 시스템 설정이 이긴다.
    ///
    /// - `reduceMotion`: 기기 기울임 패럴랙스는 전정기관 충돌 계열이라 완전히 멈춘다.
    ///   콜백 자체를 켜지 않으므로 배터리도 같이 아낀다.
    /// - `isVoiceOverRunning`: 화면을 안 보는 사용자에게 회전은 순수 소모이고,
    ///   탐색 중 카드가 혼자 움직이면 포커스 맥락이 흐려진다.
    /// - `scenePhase`: `onDisappear` 는 백그라운드 진입 때 돌지 않는다. 제어센터·알림을
    ///   끌어내린 구간에서 센서가 계속 도는 것을 막는다.
    static func shouldRunGyro(
        isEnabled: Bool,
        reduceMotion: Bool,
        isVoiceOverRunning: Bool,
        scenePhase: ScenePhase,
        isHardwareAvailable: Bool
    ) -> Bool {
        isEnabled
            && !reduceMotion
            && !isVoiceOverRunning
            && scenePhase == .active
            && isHardwareAvailable
    }

    /// 2D 폴백 여부.
    ///
    /// 접근성 글자 크기에서는 **로드조차 시작하지 않고** 2D 로 간다. 3D 텍스트는 메시라
    /// Dynamic Type 에 반응하지 못하는데, 2D 카드는 최소 높이를 바닥으로 두고 늘어난다.
    /// 여기서 3D 를 쓰면 접근성 회귀다.
    ///
    /// 로딩·실패도 2D 다. 스피너 대신 **완전히 동작하는 명함**이 자리를 지키므로
    /// 사용자 관점의 지연이 0 이고, 실패했다는 사실은 사용자가 할 수 있는 일이 없어
    /// 알리지 않는다(개발자에게는 로그로 남긴다).
    static func renderMode(
        phase: CardScenePhase,
        dynamicTypeSize: DynamicTypeSize
    ) -> CardRenderMode {
        guard !dynamicTypeSize.isAccessibilitySize else { return .twoDimensional }
        return phase == .ready ? .threeDimensional : .twoDimensional
    }
}
