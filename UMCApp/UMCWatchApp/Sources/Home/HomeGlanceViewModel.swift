import Observation

// MARK: - HomeGlanceViewModel

/// 홈 통합 글랜스의 표시 로직. 카운트 문구·출석 진입 경로를 여기서 결정한다.
@Observable
final class HomeGlanceViewModel {

    // MARK: - Property

    private(set) var glance: WatchGlance
    /// iPhone 연결 상태. `WatchSessionCoordinator.isReachable` 을 View 가 동기화한다 —
    /// 이 클래스는 SwiftUI 환경을 모르므로 값만 받아 파생 표시값을 계산한다.
    private(set) var isPhoneReachable: Bool

    var hasSession: Bool { glance.session != nil }

    /// 출석 tap-chip 목적지. 오늘 세션이 있으면 그 세션으로, 없으면 목록으로 보낸다.
    var attendanceRoute: WatchRoute {
        guard let session = glance.session else { return .attendanceList }
        return .attendanceSession(scheduleID: session.id)
    }

    var pendingApprovalLabel: String? {
        let count = Self.count(glance.pendingApprovalCount)
        return count > 0 ? "승인 대기 \(count)건" : nil
    }

    var hasUnreadPing: Bool { Self.count(glance.unreadPingCount) > 0 }

    var unreadPingLabel: String {
        let count = Self.count(glance.unreadPingCount)
        return count > 0 ? "미확인 \(count)건" : "새 공지 없음"
    }

    /// iPhone 연결이 끊기면 지금 보이는 값이 마지막으로 받은 캐시임을 문구로도 알린다 —
    /// P0-3 폴백 화면에 들어가기 전에도 글랜스 자체가 "오래된 값일 수 있다"는 신호를 준다.
    var emptySessionMessage: String {
        isPhoneReachable ? "오늘 세션 없음" : "오늘 세션 없음 (마지막 동기화 기준)"
    }

    /// P0-3 폴백 진입 행 노출 여부. 연결이 살아 있으면 노출하지 않는다.
    var showsPhoneDisconnectedRow: Bool { !isPhoneReachable }

    // MARK: - Init

    // 데이터 로딩 경로는 #1210 이 붙인다 — 지금은 주입된 값을 그대로 표시한다.
    init(glance: WatchGlance = .empty, isPhoneReachable: Bool = true) {
        self.glance = glance
        self.isPhoneReachable = isPhoneReachable
    }

    // MARK: - Function

    /// 카운트는 전 레이어 String 이고(절대 규칙 #2), Int 변환은 이 비교 시점에서만 한다.
    /// 숫자가 아니거나 음수인 값은 0건으로 취급한다 — 글랜스가 빈 문자열 하나로 깨지면 안 된다.
    private static func count(_ rawValue: String) -> Int {
        max(Int(rawValue) ?? 0, 0)
    }

    /// `WatchSessionCoordinator.isReachable` 변화를 View 가 동기화할 때 호출한다.
    func setPhoneReachable(_ isReachable: Bool) {
        isPhoneReachable = isReachable
    }
}
