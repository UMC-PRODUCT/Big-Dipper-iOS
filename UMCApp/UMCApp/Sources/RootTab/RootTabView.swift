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
        .tabViewBottomAccessory { bottomAccessory }
        .environment(pathStore)
    }

    // MARK: - Function

    /// 탭바 하단 액세서리.
    ///
    /// 레거시는 탭마다 액세서리를 뒀지만, Home 일정 등록·Notice 공지 작성은 각 화면 툴바
    /// (`ToolBarCollection.AddBtn`)로 옮겨졌다. 남은 것은 운영진 ↔ 챌린저 모드 토글뿐이라
    /// Activity 탭 루트에서 권한이 있을 때만 노출한다.
    @ViewBuilder
    private var bottomAccessory: some View {
        let userSession = di.resolve(UserSessionManager.self)

        if AdminModeToggle.shouldShow(
            selectedTab: pathStore.selectedTab,
            isAtRoot: pathStore.isAtRoot(.activity),
            canToggleAdminMode: userSession.canToggleAdminMode
        ) {
            AdminModeToggle(userSession: userSession)
        }
    }

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
    /// Home/Notice/Activity/Community가 실연결 상태다. Activity와 Community는 자기 목적지
    /// (`ActivityDestination`/`CommunityDestination`) 등록까지 각 Feature 루트가 맡으므로,
    /// App은 그 화면 구성을 알지 못한 채 진입점만 걸어 준다. 반면 Home/Notice는 목적지가
    /// App 소유(`NavigationDestination`)라 push 클로저를 여기서 넘긴다.
    ///
    /// - Note: MyPage도 이식된 모듈이 있지만, 탭 실연결은 후속 이슈에서 진행한다.
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
            CommunityFeatureView()
        case .mypage:
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

// MARK: - AdminModeToggle

/// 운영진 ↔ 챌린저 모드 전환 토글.
///
/// 액세서리는 축소(`inline`)·확장(`expanded`) 두 배치를 오가므로, 확장일 때만 현재 역할
/// 배지와 좌우 여백을 더한다. 배치 값은 액세서리 콘텐츠 안에서만 유효해 별도 뷰로 뒀다.
struct AdminModeToggle: View {

    // MARK: - Property

    let userSession: UserSessionManager

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    // MARK: - Gating

    /// 토글 노출 조건.
    ///
    /// 액세서리는 탭 셸이 소유해 모든 탭에 걸쳐 있으므로 Activity 탭에서만 노출한다.
    /// 스택이 쌓인 하위 화면에서는 모드를 바꿔도 보고 있는 화면이 그대로라 루트에서만 허용하고,
    /// 운영진 권한이 없으면 전환 자체가 무의미해 숨긴다.
    static func shouldShow(
        selectedTab: NavigationTab,
        isAtRoot: Bool,
        canToggleAdminMode: Bool
    ) -> Bool {
        selectedTab == .activity && isAtRoot && canToggleAdminMode
    }

    // MARK: - Body

    var body: some View {
        Button {
            // withAnimation 으로 감싸면 ActivityView 의 무거운 콘텐츠 교체(출석 체크 ↔ 출석 현황)까지
            // 함께 애니메이션돼 두 화면이 겹쳐 보이는 잔상·경계선이 생긴다. 모드 전환은 즉시 처리한다.
            userSession.toggleAdminMode()
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: userSession.isAdminModeEnabled ? "gearshape.fill" : "gearshape")
                    .foregroundStyle(userSession.isAdminModeEnabled ? Color.indigo500 : .grey600)

                Text(userSession.isAdminModeEnabled ? "운영진 모드" : "챌린저 모드")
                    .appFont(.subheadline)
                    .foregroundStyle(Color.grey900)

                if placement == .expanded {
                    Spacer()

                    Text(userSession.currentRole.displayName)
                        .appFont(.subheadline, color: .indigo500)
                }
            }
            .padding(.horizontal, placement == .expanded ? DefaultConstant.defaultSafeHorizon : 0)
        }
    }
}
