//
//  ComplicationProvider.swift
//  UMCWatchComplication
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import WidgetKit

// MARK: - ComplicationProvider

/// 3종 위젯이 **공유**하는 단일 프로바이더.
///
/// 셋은 같은 스냅샷을 읽고 뷰만 다르다. 프로바이더를 복제하면 같은 App Group 읽기를 세 벌
/// 유지해야 하고, 리로드 타이밍이 위젯마다 어긋난다.
struct ComplicationProvider: TimelineProvider {

    // MARK: - Property

    /// 경계 시각이 없을 때의 리로드 폴백 간격. 실제 갱신의 주 동력은 WC 수신 시의
    /// `reloadAllTimelines()` 이고, 이 값은 그 경로가 끊겼을 때 워치페이스가 멈추지 않게 하는 안전망이다.
    private static let fallbackReloadInterval: TimeInterval = 60 * 60

    /// 한 번도 동기화되지 않은 상태. `generatedAt` 이 `.distantPast` 라 신선도 표시가 스스로 드러난다.
    private static let neverSyncedSnapshot = ComplicationSnapshot(
        isSignedIn: false,
        nextSession: nil,
        attendance: .none,
        unreadPingCount: 0,
        generatedAt: .distantPast
    )

    /// 워치페이스 갤러리용 표본. `#if DEBUG` 로 가리지 않는다 — 릴리스 빌드의 갤러리도 이 값을 그린다.
    private static var gallerySnapshot: ComplicationSnapshot {
        ComplicationSnapshot(
            isSignedIn: true,
            nextSession: ComplicationSession(
                scheduleId: "0",
                name: "정기 세션",
                startsAt: Date(timeIntervalSinceNow: 45 * 60),
                endsAt: Date(timeIntervalSinceNow: 165 * 60),
                attendanceWindow: nil
            ),
            attendance: .upcoming,
            unreadPingCount: 2,
            generatedAt: Date()
        )
    }

    // MARK: - Function

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), snapshot: Self.gallerySnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let snapshot = context.isPreview
            ? Self.gallerySnapshot
            : ComplicationStore.shared.load() ?? Self.neverSyncedSnapshot
        completion(ComplicationEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ComplicationEntry>) -> Void
    ) {
        let now = Date()
        let snapshot = ComplicationStore.shared.load() ?? Self.neverSyncedSnapshot
        let entries = ComplicationTimeline.entries(from: snapshot, now: now)
        let policy: TimelineReloadPolicy = entries.count > 1
            ? .atEnd
            : .after(now.addingTimeInterval(Self.fallbackReloadInterval))
        completion(Timeline(entries: entries, policy: policy))
    }
}
