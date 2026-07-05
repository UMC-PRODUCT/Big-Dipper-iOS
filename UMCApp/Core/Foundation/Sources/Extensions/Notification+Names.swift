//
//  Notification+Names.swift
//  UMCFoundation
//
//  Created by euijjang97 on 7/5/26.
//
//  앱 전역 `Notification.Name` 정의를 한곳에 모읍니다.
//  (기존 `NotificationName+App.swift` + `Error/Handler/Notification+Error.swift` 통합)
//
//  TODO: [Refactor] AppState + Environment 도입 후 NotificationCenter 기반 흐름은 제거 예정
//

import Foundation

public extension Notification.Name {

    // MARK: - Session / Auth

    /// 인증 세션이 만료되었을 때 발송되는 알림.
    ///
    /// 이 알림을 받으면 저장된 토큰을 삭제하고 로그인 화면으로 이동해야 합니다.
    static let authSessionExpired = Notification.Name("authSessionExpired")

    /// 승인 대기 상태일 때 발송되는 알림.
    ///
    /// 이 알림을 받으면 승인 대기 안내 화면으로 이동해야 합니다.
    static let navigateToPendingApproval = Notification.Name("navigateToPendingApproval")

    // MARK: - Domain Updates

    /// 출석 승인/반려 상태 변경 알림.
    ///
    /// 운영진이 출석을 승인/반려하면 발송됩니다.
    /// 챌린저 ViewModel이 수신하여 `myHistory`를 갱신합니다.
    static let attendanceStatusChanged = Notification.Name("attendanceStatusChanged")

    /// 기수 매핑 정보가 갱신되었을 때 발송되는 알림.
    static let generationMappingsUpdated = Notification.Name("generationMappingsUpdated")
}
