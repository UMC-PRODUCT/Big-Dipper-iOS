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

    @State private var coordinator = WatchSessionCoordinator()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { coordinator.activate() }
                .syncsComplication(with: coordinator)
        }
    }
}
