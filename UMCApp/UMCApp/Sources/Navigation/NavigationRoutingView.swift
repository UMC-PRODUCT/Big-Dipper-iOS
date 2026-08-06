//
//  NavigationRoutingView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import ActivityPresentation
import CoreDI
import CoreRouting
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
    // `NoticePresentation` 이 같은 이름의 로컬 스텁을 아직 들고 있어 모듈을 명시한다.
    @Environment(CoreRouting.PathStore.self) private var pathStore
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
        case .scheduleDetail(let scheduleId):
            ScheduleDetailView(
                container: di,
                scheduleId: scheduleId,
                onAttendanceStatusTapped: {
                    // 출석 현황은 Activity 탭이 소유한 목적지라, 탭을 옮긴 뒤 그 탭 스택에 쌓는다.
                    pathStore.selectedTab = .activity
                    pathStore.push(
                        ActivityDestination.attendanceDetail(scheduleId: scheduleId),
                        on: .activity
                    )
                }
            )
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
