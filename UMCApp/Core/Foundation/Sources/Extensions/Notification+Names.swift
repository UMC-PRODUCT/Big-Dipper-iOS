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

    /// 멤버 프로필이 로컬 저장소에 동기화되었을 때 발송되는 알림.
    ///
    /// `AppDelegate`가 수신해 FCM 토큰을 재동기화합니다. 앱 실행 직후에는 `memberId`가 없어
    /// 토큰 등록이 건너뛰어지므로, 같은 세션에서 로그인한 사용자를 위한 재시도 트리거입니다.
    static let memberProfileUpdated = Notification.Name("memberProfileUpdated")

    // MARK: - Domain Updates

    /// 출석 승인/반려 상태 변경 알림.
    ///
    /// 생산자는 둘입니다 — 운영진 기기에서 승인/반려한 직후의 로컬 post 와, 챌린저 기기가
    /// 받은 출석 상태 변경 푸시(`AppDelegate`)입니다.
    /// Activity 탭 ViewModel이 수신하여 세션 목록을 서버 상태로 다시 맞춥니다.
    ///
    /// - Note: 푸시 경로는 대상 일정 식별자를 ``Notification/attendanceScheduleIdKey`` 로
    ///   실어 보냅니다. 수신 측은 전체 재조회라 지금은 읽지 않지만, 계약상 함께 나릅니다.
    static let attendanceStatusChanged = Notification.Name("attendanceStatusChanged")

    /// 기수 매핑 정보가 갱신되었을 때 발송되는 알림.
    static let generationMappingsUpdated = Notification.Name("generationMappingsUpdated")

    /// 멤버 상벌점이 변경(부여/삭제)되었을 때 발송되는 알림.
    ///
    /// 멤버 관리 화면에서 상벌점을 부여하거나 삭제하면 발송됩니다.
    /// 관련 화면(예: 명예의 전당)이 수신하여 목록을 갱신합니다.
    static let memberPenaltyUpdated = Notification.Name("memberPenaltyUpdated")
}

public extension Notification {

    /// ``Notification/Name/attendanceStatusChanged`` userInfo 에 실리는 일정 식별자 키.
    static let attendanceScheduleIdKey: String = "scheduleId"
}
