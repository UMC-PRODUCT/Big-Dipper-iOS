//
//  ComplicationStore.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/30/26.
//

import Foundation
import WidgetKit

// MARK: - ComplicationStore

/// 워치 앱 ↔ Complication 익스텐션 스냅샷 공유 스토어.
///
/// iOS 위젯의 `WidgetStorage`(`group.com.umc.product.widget`)를 재사용하지 않는다 —
/// App Group 컨테이너는 iPhone 과 워치가 공유하지 않아서, 워치 전용 그룹이 따로 필요하다.
public final class ComplicationStore: Sendable {

    // MARK: - Property

    public static let shared = ComplicationStore()

    /// 워치 앱과 익스텐션 entitlements 양쪽에 같은 값이 들어가야 한다. 어긋나면 저장은 성공한 것처럼
    /// 보이는데 익스텐션이 읽는 컨테이너가 달라 워치페이스가 영원히 비어 있다.
    public static let appGroupIdentifier = "group.com.umc.product.watch"

    private static let snapshotKey = "complication.snapshot"

    nonisolated(unsafe) private let defaults: UserDefaults?

    // MARK: - Init

    public init(suiteName: String = ComplicationStore.appGroupIdentifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    // MARK: - Function

    public func load() -> ComplicationSnapshot? {
        guard
            let defaults,
            let data = defaults.data(forKey: Self.snapshotKey)
        else { return nil }
        return try? WatchEnvelope.jsonDecoder.decode(ComplicationSnapshot.self, from: data)
    }

    /// 저장한 뒤 워치페이스 타임라인을 즉시 다시 로드한다.
    ///
    /// 저장과 리로드를 갈라 두면 새 호출자가 리로드를 빠뜨려 「값은 바뀌었는데 워치페이스는 옛날 것」이
    /// 된다. 워치는 서버를 직접 폴링하지 않아 이 경로가 갱신의 유일한 동력이다.
    public func save(_ snapshot: ComplicationSnapshot) {
        guard
            let defaults,
            let data = try? WatchEnvelope.jsonEncoder.encode(snapshot)
        else { return }
        defaults.set(data, forKey: Self.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func clear() {
        defaults?.removeObject(forKey: Self.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
