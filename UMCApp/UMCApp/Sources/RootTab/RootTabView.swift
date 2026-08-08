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
import CoreDI
import CoreDomain
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
/// - `NavigationDestination`: App 이 아직 들고 있는 Home/Notice 경로
/// - Feature 소유 목적지(예: `ActivityDestination`): 해당 Feature 루트가 자기 스택에 직접 등록
///
/// `PathStore` 가 타입 소거 `NavigationPath` 를 쓰기 때문에 두 갈래가 한 스택에 공존한다.
struct RootTabView: View {

    // MARK: - Property

    @State private var pathStore = PathStore()

    @Environment(\.di) private var di

    // MARK: - Computed Property

    private var userSession: UserSessionManager {
        di.resolve(UserSessionManager.self)
    }

    /// Activity 탭 하단 액세서리(운영진 모드 전환 토글) 노출 여부.
    ///
    /// 릴리스 빌드에서 운영진 섹션(출석/스터디/멤버 관리)에 도달하는 유일한 경로다.
    /// 게이팅 규칙은 ``ActivityAccessoryVisibility`` 참조.
    private var isActivityAccessoryVisible: Bool {
        ActivityAccessoryVisibility.isVisible(
            selectedTab: pathStore.selectedTab,
            isActivityTabAtRoot: pathStore.isAtRoot(.activity),
            canToggleAdminMode: userSession.canToggleAdminMode
        )
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $pathStore.selectedTab) {
            ForEach(NavigationTab.allCases) { tab in
                Tab(value: tab, role: tab.role) {
                    tabRootView(tab)
                } label: {
                    tabLabel(tab)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: isActivityAccessoryVisible) {
            ActivityModeAccessoryView(userSession: userSession)
        }
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
                    NavigationRoutingView(
                        destination: destination,
                        push: { pathStore.push($0, on: tab) }
                    )
                }
        }
    }

    /// 탭별 루트 화면. 실연결된 탭은 Feature 화면을, 아직인 탭은 placeholder를 표시한다.
    ///
    /// Home/Notice/Activity가 실연결 상태다. Activity는 자기 목적지(`ActivityDestination`) 등록까지
    /// `ActivityFeatureView`가 맡으므로, App은 그 화면 구성을 알지 못한 채 진입점만 걸어 준다.
    /// 반면 Home/Notice는 목적지가 App 소유(`NavigationDestination`)라 push 클로저를 여기서 넘긴다.
    ///
    /// - Note: Community/MyPage도 이식된 모듈이 있지만, 탭 실연결은 각 후속 이슈에서 진행한다.
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
                },
                onScheduleRegistrationTapped: {
                    pathStore.push(NavigationDestination.home(.registrationSchedule), on: .home)
                }
            )
        case .notice:
            NoticeFeatureView(
                onNoticeSelected: { detailItem in
                    pathStore.push(
                        NavigationDestination.notice(.detail(detailItem: detailItem)),
                        on: .notice
                    )
                },
                onStaffNoticeSelected: {
                    pathStore.push(NavigationDestination.notice(.staffNotice), on: .notice)
                }
            )
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
