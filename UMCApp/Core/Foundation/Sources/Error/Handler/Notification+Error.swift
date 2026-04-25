//
//  Notification+Error.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

// MARK: - Error Notification Names

// TODO: [Refactor] AppState 도입 후 제거 예정 - [25.01.07] 이재원
extension Notification.Name {
    /// 인증 세션이 만료되었을 때 발송되는 알림.
    ///
    /// 이 알림을 받으면 저장된 토큰을 삭제하고 로그인 화면으로 이동해야 합니다.
    public static let authSessionExpired = Notification.Name("authSessionExpired")

    /// 승인 대기 상태일 때 발송되는 알림.
    ///
    /// 이 알림을 받으면 승인 대기 안내 화면으로 이동해야 합니다.
    public static let navigateToPendingApproval = Notification.Name("navigateToPendingApproval")

    /// 출석 승인/반려 상태 변경 알림.
    ///
    /// 운영진이 출석을 승인/반려하면 발송됩니다.
    /// 챌린저 ViewModel이 수신하여 `myHistory`를 갱신합니다.
    public static let attendanceStatusChanged = Notification.Name("attendanceStatusChanged")

}
