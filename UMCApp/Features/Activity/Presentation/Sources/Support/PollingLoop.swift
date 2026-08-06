//
//  PollingLoop.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/20/26.
//

import Foundation

/// 화면 폴링 공용 루프 (sleep-first)
///
/// 매 주기 `predicate 평가 → 간격 대기 → 취소 확인 → refresh` 순서로 반복하고,
/// predicate 가 거짓이 되거나 Task 가 취소되면 종료합니다.
/// `.task` 에서 호출하면 뷰 소멸 시 자동 취소됩니다.
///
/// - 첫 refresh 는 한 주기 뒤에 실행됩니다. 진입 즉시 1회 갱신(refresh-first)이 필요하면
///   루프 시작 전에 refresh 를 직접 1회 실행합니다 — 순서 조합으로 표현하므로 별도 플래그
///   파라미터를 두지 않습니다.
/// - 대기 중 predicate 가 거짓으로 바뀌면 종료 전에 refresh 가 1회 더 실행될 수 있습니다.
///   호출부 refresh 는 배경 갱신(실패 무시·latest-wins)이어야 안전합니다.
enum PollingLoop {

    /// 폴링 루프를 시작합니다.
    ///
    /// - Parameters:
    ///   - intervalSeconds: 갱신 간격 (초)
    ///   - predicate: 매 주기 시작 시 평가해 거짓이면 루프를 종료한다.
    ///   - refresh: 주기마다 실행할 배경 갱신.
    @MainActor
    static func run(
        intervalSeconds: Int,
        while predicate: () -> Bool,
        refresh: () async -> Void
    ) async {
        while !Task.isCancelled {
            guard predicate() else { return }
            try? await Task.sleep(for: .seconds(intervalSeconds))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }
}
