//
//  MaintenanceViewModel.swift
//  MaintenancePresentation
//
//  Created by euijjang97 on 7/10/26.
//

import CoreDI
import Foundation
import MaintenanceDomain

/// 앱 루트에서 원격 킬스위치(점검)·강제 업데이트 오버레이를 판정하는 ViewModel.
///
/// 핵심 규칙 #1에 따라 `@Observable`을 사용한다. 이 화면은 `AppFlowState`와 무관하게
/// 앱 생명주기 내내 지속적으로 재확인되어야 하므로, `AppFlowViewModel`과 동일하게
/// `UMCAppApp`이 Scene 레벨에서 직접 소유하는 예외로 취급한다(그래서 `public`).
@MainActor
@Observable
public final class MaintenanceViewModel {

    // MARK: - Property

    private let checkMaintenanceUseCase: CheckMaintenanceUseCaseProtocol
    private let checkForceUpdateUseCase: CheckForceUpdateUseCaseProtocol

    public private(set) var maintenanceInfo: MaintenanceInfo?
    public private(set) var needsForceUpdate = false
    private var isChecking = false

    // MARK: - Init

    public init(container: DIContainer) {
        self.checkMaintenanceUseCase = container.resolve(CheckMaintenanceUseCaseProtocol.self)
        self.checkForceUpdateUseCase = container.resolve(CheckForceUpdateUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 점검·강제 업데이트 상태를 재확인한다. 이미 확인 중이면 무시한다.
    public func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        maintenanceInfo = await checkMaintenanceUseCase.execute()
        needsForceUpdate = await checkForceUpdateUseCase.execute()
    }
}

// MARK: - Overlay

extension MaintenanceViewModel {
    /// 앱 루트가 노출해야 할 오버레이. 점검이 강제 업데이트보다 우선한다
    /// (점검 중에는 최신 버전이어도 어차피 서비스를 이용할 수 없기 때문).
    public var overlayKind: MaintenanceOverlayKind? {
        if let maintenanceInfo, maintenanceInfo.isActive {
            return .maintenance(maintenanceInfo)
        }
        if needsForceUpdate {
            return .forceUpdate
        }
        return nil
    }
}
