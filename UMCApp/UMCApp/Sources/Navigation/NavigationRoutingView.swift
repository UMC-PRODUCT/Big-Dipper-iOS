//
//  NavigationRoutingView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import CoreDI
import NoticePresentation
import SwiftUI
import UMCFoundation

/// `NavigationDestination`을 받아 실제 목적지 화면으로 라우팅하는 뷰.
///
/// 각 탭의 `NavigationStack`이 `.navigationDestination(for: NavigationDestination.self)`에서
/// 공통으로 사용한다.
struct NavigationRoutingView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler
    private let destination: NavigationDestination

    // MARK: - Init

    init(destination: NavigationDestination) {
        self.destination = destination
    }

    // MARK: - Body

    var body: some View {
        switch destination {
        case .notice(let route):
            noticeView(route)
        }
    }
}

// MARK: - Notice Routing

private extension NavigationRoutingView {
    @ViewBuilder
    func noticeView(_ route: NavigationDestination.Notice) -> some View {
        switch route {
        case .detail(let detailItem):
            NoticeDetailView(container: di, errorHandler: errorHandler, model: detailItem)
        case .staffNotice, .editor:
            // StaffNoticeView / NoticeEditorView 자체는 NoticePresentation에 이식됐지만,
            // 두 화면은 로컬 `NoticeNavigation.PathStore`로 push되므로 이 라우터를 타지 않는다.
            // Notice 탭 실연결 후속 이슈에서 목적지 타입을 일원화하며 함께 연결한다.
            Text("아직 지원하지 않는 화면입니다")
        }
    }
}
