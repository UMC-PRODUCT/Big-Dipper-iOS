import Foundation

// MARK: - WatchRoute

/// 워치 네비게이션 스택의 목적지.
///
/// 각 케이스는 **플로우 진입점 + 식별자**만 담는다. 정시/지각/지오펜스 이탈, 읽음 여부 같은
/// 화면 내부 상태는 목적지 화면이 데이터에서 파생하므로 케이스로 쪼개지 않는다.
/// 그래서 후속 이슈(#1207·#1208·#1209)는 케이스를 추가하지 않고 `WatchRootView` 의
/// destination 만 실제 화면으로 바꿔 끼우면 된다.
public enum WatchRoute: Hashable, Sendable {
    /// #1207 출석 목록.
    case attendanceList
    /// #1207 출석 진행(정시·지각·지오펜스 이탈).
    /// 서버가 정수 식별자를 String 으로 내려주므로 전 레이어 String 이다 (절대 규칙 #2).
    case attendanceSession(scheduleID: String)
    /// #1207 출석 결과(출석·지각·공결·결석).
    case attendanceResult(scheduleID: String)
    /// #1208 The Ping 목록.
    case pingList
    /// #1208 The Ping 읽기·수신 확인.
    case pingDetail(noticeID: String)
    /// #1209 폴백 화면.
    case fallback(WatchFallbackRoute)

    /// 화면 제목. 플레이스홀더 화면과 접근성 낭독에 함께 쓴다.
    public var title: String {
        switch self {
        case .attendanceList:    "출석"
        case .attendanceSession: "출석 체크"
        case .attendanceResult:  "출석 결과"
        case .pingList:          "공지"
        case .pingDetail:        "공지 상세"
        case .fallback(let route): route.title
        }
    }
}

// MARK: - WatchFallbackRoute

/// #1209 폴백 경로. 워치 단독으로는 진행할 수 없는 상태를 사용자에게 설명하는 화면들이다.
public enum WatchFallbackRoute: Hashable, Sendable, CaseIterable {
    /// P0-1 위치 권한 거부.
    case locationPermissionDenied
    /// P0-3 iPhone 연결 끊김.
    case phoneDisconnected
    /// P0-7 오프라인 큐잉.
    case offlineQueue

    /// 화면 제목.
    public var title: String {
        switch self {
        case .locationPermissionDenied: "위치 권한 필요"
        case .phoneDisconnected:        "iPhone 연결 끊김"
        case .offlineQueue:             "전송 대기 중"
        }
    }
}
