//
//  RootTabView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import ActivityPresentation
import CommunityPresentation
import CoreDesignSystem
import HomePresentation
import MyPagePresentation
import NoticePresentation
import SwiftUI

/// `.main` 상태의 루트 탭 셸.
///
/// Home/Notice/Activity/Community/MyPage 5개 탭을 탭별 독립 `NavigationStack`으로
/// 구성한다. 최소 수직 슬라이스이므로 Home 탭만 실제 화면(`HomeFeatureView`)에 연결되고,
/// 나머지 4탭은 각 Feature의 placeholder(`{Feature}FeatureView`)를 표시한다.
struct RootTabView: View {

    // MARK: - Property

    @State private var selectedTab: TabCase = .home
    @State private var pathStore = PathStore()

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabCase.allCases) { tab in
                Tab(value: tab, role: tab.role) {
                    tabRootView(tab)
                } label: {
                    tabLabel(tab)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: - Function

    private func tabLabel(_ tab: TabCase) -> some View {
        VStack(alignment: .center, spacing: DefaultSpacing.spacing8) {
            Image(systemName: tab.systemImageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Text(tab.title)
                .appFont(.caption1, weight: .regular)
        }
    }

    /// 탭 케이스에 따른 루트 뷰를 독립 `NavigationStack`으로 감싼다.
    @ViewBuilder
    private func tabRootView(_ tab: TabCase) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            tabContent(tab)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    NavigationRoutingView(destination: destination)
                }
        }
    }

    /// Home 탭만 실제 화면에 연결하고, 나머지는 각 Feature의 placeholder를 표시한다.
    ///
    /// - Note: Notice/MyPage는 이미 이식된 모듈이 있지만, 탭 실연결은 후속 이슈에서
    ///   진행한다(#910 범위 밖).
    @ViewBuilder
    private func tabContent(_ tab: TabCase) -> some View {
        switch tab {
        case .home:
            HomeFeatureView(
                onNoticeSelected: { detailItem in
                    pathStore.homePath.append(.notice(.detail(detailItem: detailItem)))
                },
                onScheduleSelected: { scheduleId in
                    pathStore.homePath.append(.home(.scheduleDetail(scheduleId: scheduleId)))
                },
                onAlarmHistoryTapped: {
                    pathStore.homePath.append(.home(.alarmHistory))
                }
            )
        case .notice:
            // TODO: NoticePresentation의 실제 NoticeView 연결 (Notice 탭 실연결 후속 이슈)
            NoticeFeatureView()
        case .activity:
            // TODO: ActivityPresentation의 실제 ActivityView 연결 (Activity 탭 실연결 후속 이슈)
            ActivityFeatureView()
        case .community:
            // TODO: CommunityPresentation의 실제 CommunityView 연결 (Community 탭 실연결 후속 이슈)
            CommunityFeatureView()
        case .mypage:
            // TODO: MyPagePresentation의 실제 MyPageView 연결 (MyPage 탭 실연결 후속 이슈)
            MyPageFeatureView()
        }
    }

    /// 탭별 독립 `NavigationStack` path 바인딩을 `PathStore`에 위임한다.
    private func pathBinding(for tab: TabCase) -> Binding<[NavigationDestination]> {
        switch tab {
        case .home:
            Binding(get: { pathStore.homePath }, set: { pathStore.homePath = $0 })
        case .notice:
            Binding(get: { pathStore.noticePath }, set: { pathStore.noticePath = $0 })
        case .activity:
            Binding(get: { pathStore.activityPath }, set: { pathStore.activityPath = $0 })
        case .community:
            Binding(get: { pathStore.communityPath }, set: { pathStore.communityPath = $0 })
        case .mypage:
            Binding(get: { pathStore.myPagePath }, set: { pathStore.myPagePath = $0 })
        }
    }
}
