//
//  ActivityAccessoryVisibility.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/9/26.
//

import CoreRouting

/// Activity 탭 하단 액세서리(운영진 모드 전환 토글) 노출 여부를 결정하는 순수 규칙.
///
/// 액세서리는 Activity 탭이 선택돼 있고, 그 탭의 NavigationStack이 루트이며, 사용자가
/// 운영진 모드로 전환 가능할 때만 보인다 (레거시 `UmcTab.shouldShowAccessory()` 동등).
enum ActivityAccessoryVisibility {

    // MARK: - Function

    static func isVisible(
        selectedTab: NavigationTab,
        isActivityTabAtRoot: Bool,
        canToggleAdminMode: Bool
    ) -> Bool {
        selectedTab == .activity && isActivityTabAtRoot && canToggleAdminMode
    }
}
