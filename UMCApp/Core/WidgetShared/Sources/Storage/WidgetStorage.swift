//
//  WidgetStorage.swift
//  CoreWidgetShared
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

/// App Group 기반 위젯 공유 스토리지 래퍼
///
/// `group.com.umc.product.widget` App Group을 통해
/// 메인 앱과 Widget Extension 간 데이터를 공유합니다.
public final class WidgetStorage: Sendable {

    // MARK: - Property

    public static let shared = WidgetStorage()

    private static let appGroupSuiteName = "group.com.umc.product.widget"

    nonisolated(unsafe) private let defaults: UserDefaults?

    // MARK: - Init

    public init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupSuiteName)
    }

    // MARK: - Function

    public func save<T: Encodable>(_ value: T, forKey key: WidgetStorageKey) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: WidgetStorageKey) -> T? {
        guard let defaults,
              let data = defaults.data(forKey: key.rawValue) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }

    public func remove(forKey key: WidgetStorageKey) {
        defaults?.removeObject(forKey: key.rawValue)
    }
}

// MARK: - WidgetStorageKey

public enum WidgetStorageKey: String, Sendable {
    case scheduleEntry = "widget.scheduleEntry"
    case attendanceEntry = "widget.attendanceEntry"
    case noticeEntry = "widget.noticeEntry"
}
