import Foundation
import CoreWatchDesignSystem

// MARK: - WatchGlance

/// 홈 통합 글랜스 표시 모델. 데이터 공급은 #1210(WatchConnectivity 페이로드 계약)이 붙인다.
struct WatchGlance: Equatable, Sendable {

    /// `nil` 이면 오늘 세션이 없다.
    let session: GlanceSession?
    /// 승인 대기 건수. 서버가 정수를 String 으로 내려주므로 그대로 String 이다 (절대 규칙 #2).
    let pendingApprovalCount: String
    /// 미확인 The Ping 건수.
    let unreadPingCount: String

    static let empty = WatchGlance(
        session: nil,
        pendingApprovalCount: "0",
        unreadPingCount: "0"
    )
}

// MARK: - GlanceSession

struct GlanceSession: Equatable, Sendable, Identifiable {

    /// 스케줄 식별자 (절대 규칙 #2 — 서버 정수는 전 레이어 String).
    let id: String
    let title: String
    let startsAt: Date
    let status: WatchStatus
}

#if DEBUG
extension WatchGlance {

    static let sample = WatchGlance(
        session: .sample,
        pendingApprovalCount: "3",
        unreadPingCount: "2"
    )

    static let noSession = WatchGlance(
        session: nil,
        pendingApprovalCount: "0",
        unreadPingCount: "1"
    )

    static let pending = WatchGlance(
        session: .sample,
        pendingApprovalCount: "5",
        unreadPingCount: "0"
    )
}

extension GlanceSession {

    static let sample = GlanceSession(
        id: "1024",
        title: "5주차 정기 세션",
        startsAt: .now.addingTimeInterval(30 * 60),
        status: .active
    )
}
#endif
