//
//  UserSessionManager.swift
//  CoreDomain
//
//  Created by euijjang97 on 7/10/26.
//

import Foundation
import UMCFoundation

/// Activity 화면의 모드
public enum ActivityMode: String, CaseIterable, Sendable {
    case challenger
    case admin
}

/// 앱 전역에서 공유하는 현재 로그인 사용자의 세션·권한 상태.
///
/// `SyncProfileStorageUseCase`가 프로필 동기화 시점에 갱신하며, Notice 등 권한 분기가
/// 필요한 화면에서 관찰한다. Activity 화면의 Challenger/Admin 모드 전환 상태도 함께 관리한다
/// (레거시 `AppProduct` `UserSessionManager` 의미 동등, #959).
@Observable
public final class UserSessionManager {

    // MARK: - Property

    /// 현재 사용자의 최고 권한 역할 (서버에서 받아온 실제 권한)
    public private(set) var currentRole: ManagementTeam = .challenger

    /// 사용자가 보유한 전체 역할 목록
    public private(set) var allRoles: [ManagementTeam] = []

    /// Admin 모드 활성화 여부
    public private(set) var isAdminModeEnabled: Bool = false

    // MARK: - Computed Property

    /// Admin 모드 토글 가능 여부
    public var canToggleAdminMode: Bool {
        currentRole.canAccessAdminMode
    }

    /// 현재 활성화된 Activity 모드
    public var currentActivityMode: ActivityMode {
        isAdminModeEnabled ? .admin : .challenger
    }

    // MARK: - Init

    public init() {}

    // MARK: - Function

    /// Admin 모드 토글
    public func toggleAdminMode() {
        guard canToggleAdminMode else { return }
        isAdminModeEnabled.toggle()
    }

    /// 사용자 역할 업데이트 (로그인/세션 복원 시 호출)
    public func updateRole(_ role: ManagementTeam, allRoles: [ManagementTeam] = []) {
        currentRole = role
        self.allRoles = allRoles.isEmpty ? [role] : allRoles
        // Admin 모드 접근 불가 역할로 변경되면 Admin 모드 비활성화
        if !role.canAccessAdminMode {
            isAdminModeEnabled = false
        }
    }

    /// 보유 역할 중 특정 권한이 있는지 확인
    public func hasAnyRole(where predicate: (ManagementTeam) -> Bool) -> Bool {
        allRoles.contains(where: predicate)
    }

    /// 세션 초기화 (로그아웃/탈퇴 시 호출)
    public func reset() {
        currentRole = .challenger
        allRoles = []
        isAdminModeEnabled = false
    }
}
