//
//  MaintenanceOverlayKind.swift
//  MaintenancePresentation
//
//  Created by euijjang97 on 7/10/26.
//

import MaintenanceDomain

/// `MaintenanceView`가 렌더링해야 할 앱 루트 오버레이 종류.
public enum MaintenanceOverlayKind: Equatable {
    /// 원격 킬스위치로 인한 점검 중 — 사용자에게 점검 안내를 노출한다.
    case maintenance(MaintenanceInfo)
    /// 최소 지원 버전 미달로 인한 강제 업데이트 유도.
    case forceUpdate
}
