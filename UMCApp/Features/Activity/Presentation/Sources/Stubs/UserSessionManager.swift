//
//  UserSessionManager.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import UMCFoundation

/// 현재 사용자 세션의 역할을 보관하는 임시 매니저.
///
/// 멤버 관리 화면이 현재 사용자 권한 레벨로 부여 가능한 상벌점 유형을 계산하기 위해
/// 사용합니다. 앱 전역 공통 세션 매니저가 도입되기 전까지의 모듈 로컬 스텁입니다.
// TODO: 앱 타겟 공통 세션 매니저로 교체 - [26.06.28] 이재원
@Observable
public final class UserSessionManager {

    public private(set) var currentRole: ManagementTeam = .challenger

    public init() {}

    public func updateRole(_ role: ManagementTeam) {
        currentRole = role
    }
}
