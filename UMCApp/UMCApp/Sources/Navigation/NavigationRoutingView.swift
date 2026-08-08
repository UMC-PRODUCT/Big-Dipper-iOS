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
    @Environment(PathStore.self) private var pathStore
    private let destination: NavigationDestination
    /// 라우팅된 화면이 다시 push를 요청할 때 호출하는 콜백. 진입 탭의 path에 append된다.
    private let push: (NavigationDestination) -> Void

    // MARK: - Init

    init(destination: NavigationDestination, push: @escaping (NavigationDestination) -> Void) {
        self.destination = destination
        self.push = push
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
        case .registrationSchedule:
            ScheduleRegistrationView(container: di)
        case .scheduleDetail(let scheduleId):
            ScheduleDetailView(
                container: di,
                errorHandler: errorHandler,
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
            NoticeDetailView(
                container: di,
                errorHandler: errorHandler,
                model: detailItem,
                onEditRequested: { mode in
                    push(.notice(.editor(mode: mode, selectedGisuId: nil)))
                }
            )
        case .staffNotice:
            StaffNoticeView(
                container: di,
                errorHandler: errorHandler,
                onNoticeSelected: { detailItem in
                    push(.notice(.detail(detailItem: detailItem)))
                },
                onCreateNotice: { gisuId, category in
                    push(.notice(.editor(
                        mode: .create,
                        selectedGisuId: gisuId,
                        initialCategory: category
                    )))
                }
            )
        case .editor(let mode, let selectedGisuId, let initialCategory):
            NoticeEditorView(
                container: di,
                mode: mode,
                selectedGisuId: selectedGisuId,
                initialCategory: initialCategory
            )
        }
    }
}
