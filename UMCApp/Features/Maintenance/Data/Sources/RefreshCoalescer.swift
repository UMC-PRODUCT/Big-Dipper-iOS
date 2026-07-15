//
//  RefreshCoalescer.swift
//  MaintenanceData
//
//  Created by euijjang97 on 7/10/26.
//

import Foundation

/// 짧은 시간 내에 연속 호출되는 비동기 작업을 하나의 실행으로 합쳐주는 헬퍼.
///
/// `MaintenanceViewModel.check()` 1회당 점검·강제 업데이트 두 UseCase가 순차적으로
/// `RemoteConfigService`를 호출한다. 별도 처리가 없으면 매 호출마다
/// `fetchAndActivate()`가 새로 실행되어 네트워크 왕복이 두 배로 발생한다.
///
/// - 이미 실행 중인 작업이 있으면 그 결과를 그대로 공유한다(동시 호출 대응).
/// - 방금 끝난 작업이 있으면 `coalesceWindow` 동안은 재실행하지 않고 넘어간다
///   (순차 호출 대응 — `check()` 내부의 두 번째 호출이 여기 해당한다).
actor RefreshCoalescer {

    // MARK: - Property

    private let coalesceWindow: TimeInterval
    private var inFlightTask: Task<Void, Never>?
    private var lastCompletedAt: Date?

    // MARK: - Init

    init(coalesceWindow: TimeInterval) {
        self.coalesceWindow = coalesceWindow
    }

    // MARK: - Function

    /// `operation`을 최소 한 번 실행되도록 보장한다.
    ///
    /// 이미 실행 중이거나 `coalesceWindow` 이내에 끝난 실행이 있으면 `operation`을
    /// 다시 호출하지 않고 그 결과가 반영된 상태로 반환한다.
    func run(_ operation: @escaping () async -> Void) async {
        if let inFlightTask {
            await inFlightTask.value
            return
        }
        if let lastCompletedAt, Date().timeIntervalSince(lastCompletedAt) < coalesceWindow {
            return
        }

        let task = Task {
            await operation()
        }
        inFlightTask = task
        await task.value
        inFlightTask = nil
        lastCompletedAt = Date()
    }
}
