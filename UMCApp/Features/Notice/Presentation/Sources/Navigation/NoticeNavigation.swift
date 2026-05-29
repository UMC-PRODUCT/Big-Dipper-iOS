//
//  NoticeNavigation.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import NoticeDomain

// TODO: PathStore / NavigationDestination 교체
@Observable
public final class PathStore {
    public var noticePath: [NavigationDestination] = []
    public init() {}
}

public enum NavigationDestination: Hashable {
    case notice(NoticeDestination)
}

public enum NoticeDestination: Hashable {
    case detail(detailItem: NoticeDetail)
    case staffNotice
}

public struct NavigationRoutingView: View {
    private let destination: NavigationDestination
    public init(destination: NavigationDestination) {
        self.destination = destination
    }
    public var body: some View {
        // TODO: Route to actual destination views
        Text("Navigation destination: \(String(describing: destination))")
    }
}
