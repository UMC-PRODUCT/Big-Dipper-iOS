//
//  UMCWatchApp.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 4/24/26.
//

import CoreWatchConnectivity
import SwiftUI

@main
struct UMCWatchApp: App {

    // MARK: - Property

    /// 세션은 앱 수명 하나다. 화면이 소유하면 화면 전환마다 새 코디네이터가 생기고
    /// `WCSession.default.delegate` 는 옛 인스턴스를 가리킨 채로 남는다.
    @State private var coordinator = WatchSessionCoordinator()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .task { coordinator.activate() }
        }
    }
}
