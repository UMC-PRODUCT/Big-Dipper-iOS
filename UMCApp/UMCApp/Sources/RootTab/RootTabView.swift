//
//  RootTabView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import SwiftUI

import ActivityPresentation
import CommunityPresentation
import CoreDesignSystem
import CoreRouting
import HomePresentation
import MyPagePresentation
import NoticePresentation

/// `.main` 상태의 루트 탭 셸.
///
/// Home/Notice/Activity/Community/MyPage 5개 탭을 탭별 독립 `NavigationStack`으로 구성한다.
/// 각 스택의 경로는 공유 `PathStore` 가 들고 있고, 이 뷰가 그것을 `.environment` 로 내려보내
/// Feature 가 App 을 import 하지 않고도 자기 화면을 push 할 수 있게 한다.
///
/// 목적지 렌더 분기는 두 갈래로 등록된다.
/// - `NavigationDestination`: App 이 아직 들고 있는 Notice 경로
/// - Feature 소유 목적지(예: `ActivityDestination`): 해당 Feature 루트가 자기 스택에 직접 등록
///
/// `PathStore` 가 타입 소거 `NavigationPath` 를 쓰기 때문에 두 갈래가 한 스택에 공존한다.
struct RootTabView: View {

    // MARK: - Property

    @State private var selectedTab: NavigationTab = .home

    // `NoticePresentation` 이 같은 이름의 로컬 스텁(`NoticeNavigation.swift`)을 아직 들고 있어
    // 모듈을 명시한다. Notice 탭이 공유 경로로 옮겨오면 그 스텁과 함께 접두사도 사라진다.
    @State private var pathStore = CoreRouting.PathStore()

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationTab.allCases) { tab in
                Tab(value: tab, role: tab.role) {
                    tabRootView(tab)
                } label: {
                    tabLabel(tab)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(pathStore)
    }

    // MARK: - Function

    private func tabLabel(_ tab: NavigationTab) -> some View {
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
    private func tabRootView(_ tab: NavigationTab) -> some View {
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
    private func tabContent(_ tab: NavigationTab) -> some View {
        switch tab {
        case .home:
            HomeFeatureView(
                onNoticeSelected: { detailItem in
                    pathStore.push(
                        NavigationDestination.notice(.detail(detailItem: detailItem)),
                        on: .home
                    )
                },
                onScheduleSelected: { scheduleId in
                    pathStore.push(
                        NavigationDestination.home(.scheduleDetail(scheduleId: scheduleId)),
                        on: .home
                    )
                },
                onAlarmHistoryTapped: {
                    pathStore.push(NavigationDestination.home(.alarmHistory), on: .home)
                }
            )
        case .notice:
            // TODO: NoticePresentation의 실제 NoticeView 연결 (Notice 탭 실연결 후속 이슈)
            NoticeFeatureView()
        case .activity:
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
    private func pathBinding(for tab: NavigationTab) -> Binding<NavigationPath> {
        Binding(
            get: { pathStore[tab] },
            set: { pathStore[tab] = $0 }
        )
    }
}
