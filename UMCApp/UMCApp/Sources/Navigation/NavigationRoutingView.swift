//
//  NavigationRoutingView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import CoreDI
import HomePresentation
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
        case .home(let route):
            homeView(route)
        case .notice(let route):
            noticeView(route)
        }
    }
}

// MARK: - Home Routing

private extension NavigationRoutingView {
    @ViewBuilder
    func homeView(_ route: NavigationDestination.Home) -> some View {
        switch route {
        case .alarmHistory:
            NoticeAlarmView()
        case .scheduleDetail:
            // ScheduleDetailView는 HomePresentation 이식 대상이다 (#981 에서 소유 모듈 확정).
            // 상세 화면이 리소스 권한(수정/삭제/강제삭제)에 의존하는데 AuthorizationUseCase 가
            // 아직 UMCApp 에 이식되지 않아 별도 이슈로 남는다.
            Text("아직 지원하지 않는 화면입니다")
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
            // StaffNoticeView / NoticeEditorView는 아직 NoticePresentation에 이식되지 않았다.
            Text("아직 지원하지 않는 화면입니다")
        }
    }
}
