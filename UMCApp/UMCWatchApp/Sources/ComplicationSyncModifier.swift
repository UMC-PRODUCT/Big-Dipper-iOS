//
//  ComplicationSyncModifier.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchConnectivity
import SwiftUI

// MARK: - ComplicationSyncModifier

/// WC 로 새 스냅샷이 도착할 때마다 워치페이스 스냅샷을 갱신한다.
///
/// 워치는 서버를 직접 폴링하지 않으므로 이 경로가 Complication 이 최신값을 얻는 유일한 통로다.
/// `initial: true` 인 이유는 콜드런치 시딩 때문이다 — 활성화 시점에 이미 도착해 있던
/// 컨텍스트에는 델리게이트 콜백이 다시 오지 않아, 첫 값이 그대로 누락된다.
private struct ComplicationSyncModifier: ViewModifier {

    // MARK: - Property

    let coordinator: WatchSessionCoordinator

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .onChange(of: coordinator.receivedState, initial: true) { _, state in
                guard let state else { return }
                ComplicationStore.shared.save(ComplicationSnapshot(state: state))
            }
    }
}

// MARK: - View + syncsComplication

extension View {

    func syncsComplication(with coordinator: WatchSessionCoordinator) -> some View {
        modifier(ComplicationSyncModifier(coordinator: coordinator))
    }
}
