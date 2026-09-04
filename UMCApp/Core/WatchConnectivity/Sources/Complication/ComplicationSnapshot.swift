//
//  ComplicationSnapshot.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import WidgetKit

// MARK: - ComplicationSnapshot

/// 워치페이스가 그리는 데 필요한 최소값만 담은 파생 스냅샷.
///
/// ``WatchSessionState`` 를 그대로 저장하지 않는 이유: 타임라인 리프레시마다 디코딩하는 값이라
/// 목록 전체를 실으면 매 갱신에 낭비가 붙는다. 워치페이스는 「다음 하나」와 「개수」만 그린다.
public struct ComplicationSnapshot: Codable, Sendable, Equatable {

    // MARK: - Property

    /// `false` 면 3종 모두 「iPhone 로그인 필요」를 그린다.
    public let isSignedIn: Bool
    /// 아직 끝나지 않은 일정 중 가장 이른 것. 없으면 `nil`.
    public let nextSession: ComplicationSession?
    public let attendance: ComplicationAttendanceState
    /// 미확인 The Ping 개수. 상한을 두지 않는다 — 절단(`99+`)은 뷰의 책임이다.
    public let unreadPingCount: Int
    /// 원본 스냅샷의 생성 시각. 워치페이스가 신선도를 표시한다.
    public let generatedAt: Date

    // MARK: - Init

    public init(
        isSignedIn: Bool,
        nextSession: ComplicationSession?,
        attendance: ComplicationAttendanceState,
        unreadPingCount: Int,
        generatedAt: Date
    ) {
        self.isSignedIn = isSignedIn
        self.nextSession = nextSession
        self.attendance = attendance
        self.unreadPingCount = unreadPingCount
        self.generatedAt = generatedAt
    }

    /// WC 스냅샷 → Complication 스냅샷. 순수 함수라 테스트가 규칙을 잠근다.
    public init(state: WatchSessionState, now: Date = Date()) {
        let schedule = Self.nextSchedule(in: state.schedules, now: now)
        self.init(
            isSignedIn: state.isSignedIn,
            nextSession: schedule.map(ComplicationSession.init(schedule:)),
            attendance: Self.attendanceState(for: schedule, now: now),
            unreadPingCount: state.notices.count { !$0.isRead },
            generatedAt: state.generatedAt
        )
    }

    // MARK: - Function

    /// 경계 시각 기준으로 **출석 상태만** 다시 계산한 사본.
    ///
    /// 세션·개수까지 다시 파생하지 않는 이유: 미래 시점의 일정 목록·읽음 여부는 워치가 알 수 없다.
    /// 시간이 지나기만 해도 확정적으로 바뀌는 값은 출석 창 판정뿐이다.
    func projected(at date: Date) -> ComplicationSnapshot {
        guard !attendance.isServerConfirmed else { return self }
        return ComplicationSnapshot(
            isSignedIn: isSignedIn,
            nextSession: nextSession,
            attendance: Self.windowState(nextSession?.attendanceWindow, now: date),
            unreadPingCount: unreadPingCount,
            generatedAt: generatedAt
        )
    }

    /// 끝난 세션은 워치페이스에서 의미가 없으므로 후보에서 뺀다.
    /// 진행 중인 세션은 `startsAt` 이 가장 이르므로 정렬만으로 자연히 우선한다.
    private static func nextSchedule(
        in schedules: [WatchSchedule],
        now: Date
    ) -> WatchSchedule? {
        schedules
            .filter { $0.endsAt > now }
            .min {
                $0.startsAt == $1.startsAt
                    ? $0.scheduleId < $1.scheduleId
                    : $0.startsAt < $1.startsAt
            }
    }

    private static func attendanceState(
        for schedule: WatchSchedule?,
        now: Date
    ) -> ComplicationAttendanceState {
        guard let schedule else { return .none }
        if
            let rawStatus = schedule.attendanceStatus,
            let mapped = ComplicationAttendanceState.from(rawStatus: rawStatus)
        {
            return mapped
        }
        return windowState(schedule.attendanceWindow, now: now)
    }

    /// 서버 상태가 없거나 워치가 모르는 문자열일 때의 폴백.
    /// 창이 닫혔는데 상태가 없다면 결석이다 — 「알 수 없음」으로 두면 사용자가 조치할 시점을 놓친다.
    static func windowState(
        _ window: WatchAttendanceWindow?,
        now: Date
    ) -> ComplicationAttendanceState {
        guard let window else { return .none }
        if now < window.checkInStartAt { return .upcoming }
        if now < window.lateEndAt { return .awaiting }
        return .absent
    }
}

// MARK: - ComplicationSession

public struct ComplicationSession: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 서버 정수 식별자를 String 으로 보존한다 (핵심 규칙 #2).
    public let scheduleId: String
    public let name: String
    public let startsAt: Date
    public let endsAt: Date
    /// `nil` = 출석 비필수. 타임라인 경계 시각의 유일한 출처이기도 하다.
    public let attendanceWindow: WatchAttendanceWindow?

    // MARK: - Init

    public init(
        scheduleId: String,
        name: String,
        startsAt: Date,
        endsAt: Date,
        attendanceWindow: WatchAttendanceWindow?
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.attendanceWindow = attendanceWindow
    }

    init(schedule: WatchSchedule) {
        self.init(
            scheduleId: schedule.scheduleId,
            name: schedule.name,
            startsAt: schedule.startsAt,
            endsAt: schedule.endsAt,
            attendanceWindow: schedule.attendanceWindow
        )
    }

    // MARK: - Function

    public func isInProgress(now: Date = Date()) -> Bool {
        startsAt <= now && now < endsAt
    }
}

// MARK: - ComplicationAttendanceState

/// 워치페이스가 그리는 출석 상태.
///
/// 각 케이스는 색 말고도 **심볼·라벨·링 유무**를 함께 낸다. accented(tinted) 워치페이스에서
/// 시스템이 색을 단색으로 치환하면 색으로만 구분하던 상태가 통째로 구별 불가가 되기 때문이다.
/// 색은 보조 채널이라는 원칙은 색각 이상 사용자에게도 그대로 유효하다.
public enum ComplicationAttendanceState: String, Codable, Sendable, CaseIterable {
    /// 다음 세션이 없거나 출석 비필수.
    case none
    /// 체크인 창이 아직 열리지 않음.
    case upcoming
    /// 체크인 창이 열렸고 아직 요청하지 않음.
    case awaiting
    case pending
    case present
    case late
    case excused
    case absent

    // MARK: - Property

    /// 실루엣이 서로 다른 심볼. `ComplicationSnapshotTests` 가 중복을 잠근다.
    public var symbolName: String {
        switch self {
        case .none:     "calendar"
        case .upcoming: "clock"
        case .awaiting: "location.circle"
        case .pending:  "hourglass"
        case .present:  "checkmark.circle.fill"
        case .late:     "exclamationmark.circle.fill"
        case .excused:  "checkmark.shield.fill"
        case .absent:   "xmark.circle.fill"
        }
    }

    /// inline·circular 처럼 폭이 없는 자리에서도 잘리지 않는 짧은 라벨.
    public var shortLabel: String {
        switch self {
        case .none:     "예정 없음"
        case .upcoming: "출석 예정"
        case .awaiting: "출석 가능"
        case .pending:  "승인 대기"
        case .present:  "출석"
        case .late:     "지각"
        case .excused:  "공결"
        case .absent:   "결석"
        }
    }

    /// 승인 대기와 공결은 스펙상 같은 중립색이라 색으로는 갈리지 않는다.
    /// 링은 색이 아니라 **형태**라 accented 모드에서도 살아남는다.
    public var hasPendingRing: Bool { self == .pending }

    /// 시간이 흘러도 뒤집히지 않는 확정 상태. 타임라인이 이 값을 창 판정으로 덮어쓰지 않는다.
    var isServerConfirmed: Bool {
        switch self {
        case .pending, .present, .late, .excused, .absent: true
        case .none, .upcoming, .awaiting:                  false
        }
    }

    // MARK: - Function

    /// 서버 `AttendanceStatus` 원본 문자열 → 표시 상태. 모르는 값은 `nil` 이라 창 폴백으로 떨어진다.
    ///
    /// `EXCUSED` 를 `.present` 로 합치지 않는다 — 합치는 순간 공결 사용자가 볼 화면이 사라진다.
    static func from(rawStatus: String) -> ComplicationAttendanceState? {
        switch rawStatus {
        case "PRESENT": .present
        case "LATE":    .late
        case "EXCUSED": .excused
        case "ABSENT":  .absent
        case "PENDING", "PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING": .pending
        default: nil
        }
    }
}

// MARK: - ComplicationEntry

public struct ComplicationEntry: TimelineEntry {

    // MARK: - Property

    public let date: Date
    public let snapshot: ComplicationSnapshot

    // MARK: - Init

    public init(date: Date, snapshot: ComplicationSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

// MARK: - ComplicationTimeline

/// 스냅샷 하나에서 타임라인 엔트리를 뽑는 순수 함수 모음.
///
/// 익스텐션이 아니라 여기 두는 이유: 엔트리 규칙은 스냅샷 파생 규칙의 연장이라 같은 테스트가
/// 함께 잠가야 한다. 익스텐션 타겟은 유닛 테스트에서 import 할 수 없다.
public enum ComplicationTimeline {

    // MARK: - Property

    /// 경계 엔트리 상한. 워치 리프레시 예산이 유한해서, 한 세션의 상태 전이를 덮는 최소치로 둔다.
    private static let maxBoundaryCount = 6

    // MARK: - Function

    /// `now` 엔트리 1개 + 상태가 실제로 바뀌는 시각의 엔트리들.
    ///
    /// 카운트다운 숫자로는 엔트리를 늘리지 않는다 — `Text(_:style:)` 이 시스템 쪽에서 갱신한다.
    public static func entries(
        from snapshot: ComplicationSnapshot,
        now: Date = Date()
    ) -> [ComplicationEntry] {
        [ComplicationEntry(date: now, snapshot: snapshot)]
            + boundaries(of: snapshot, after: now).map {
                ComplicationEntry(date: $0, snapshot: snapshot.projected(at: $0))
            }
    }

    private static func boundaries(of snapshot: ComplicationSnapshot, after now: Date) -> [Date] {
        guard let session = snapshot.nextSession else { return [] }
        var candidates: Set<Date> = [session.startsAt, session.endsAt]
        if let window = session.attendanceWindow {
            candidates.formUnion([window.checkInStartAt, window.onTimeEndAt, window.lateEndAt])
        }
        return Array(candidates.filter { $0 > now }.sorted().prefix(maxBoundaryCount))
    }
}

#if DEBUG
public extension ComplicationSnapshot {

    static let preview = ComplicationSnapshot(
        isSignedIn: true,
        nextSession: ComplicationSession(
            scheduleId: "1",
            name: "9주차 정기 세션",
            startsAt: Date(timeIntervalSinceNow: 45 * 60),
            endsAt: Date(timeIntervalSinceNow: 165 * 60),
            attendanceWindow: WatchAttendanceWindow(
                checkInStartAt: Date(timeIntervalSinceNow: 30 * 60),
                onTimeEndAt: Date(timeIntervalSinceNow: 55 * 60),
                lateEndAt: Date(timeIntervalSinceNow: 75 * 60)
            )
        ),
        attendance: .upcoming,
        unreadPingCount: 3,
        generatedAt: Date()
    )

    static let signedOut = ComplicationSnapshot(
        isSignedIn: false,
        nextSession: nil,
        attendance: .none,
        unreadPingCount: 0,
        generatedAt: Date()
    )
}
#endif
