//
//  UserSessionManager.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation

// TODO: 앱 타겟 공통 매니저로 교체
@Observable
public final class UserSessionManager {
    public private(set) var currentRole: ManagementTeam = .challenger
    public init() {}
    public func updateRole(_ role: ManagementTeam) { currentRole = role }
}
