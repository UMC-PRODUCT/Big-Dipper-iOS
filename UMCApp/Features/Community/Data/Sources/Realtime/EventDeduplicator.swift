//
//  EventDeduplicator.swift
//  CommunityData
//

import Foundation

/// 서버가 재시도로 같은 이벤트를 두 번 보낼 수 있어 `eventId` 로 걸러 낸다.
///
/// 세션이 길어져도 메모리가 늘지 않도록 최근 `capacity` 개만 기억하는 FIFO 다.
/// 이 값을 넘길 만큼 옛 이벤트가 재도착하는 일은 없다 — 그런 공백은 재연결 후 REST 백필이 메운다.
struct EventDeduplicator {

    // MARK: - Property

    private var seen: Set<String> = []
    private var order: [String] = []
    private let capacity: Int

    // MARK: - Init

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    // MARK: - Function

    /// 처음 보는 `eventId` 면 기록하고 `true`, 이미 본 것이면 `false`.
    mutating func shouldProcess(_ eventId: String) -> Bool {
        guard !seen.contains(eventId) else { return false }

        seen.insert(eventId)
        order.append(eventId)

        if order.count > capacity {
            seen.remove(order.removeFirst())
        }
        return true
    }
}
