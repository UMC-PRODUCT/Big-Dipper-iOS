//
//  RootTabView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import SwiftUI

import ActivityPresentation
import CommunityDomain
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
    @Environment(DeepLinkStore.self) private var deepLinkStore

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
        .tabViewBottomAccessory(isEnabled: shouldShowAccessory) {
            RootTabAccessoryView(pathStore: pathStore)
        }
        .environment(pathStore)
        // 앱이 켜져 있는 동안 도착한 링크와, 로그인 화면에 머무는 사이 밀려 있던 링크를
        // 같은 함수로 받는다. 후자는 이 뷰가 처음 뜨는 시점에 한 번 꺼내면 된다.
        .task { consumePendingDeepLink() }
        .onChange(of: deepLinkStore.pending) { _, _ in consumePendingDeepLink() }
    }

    // MARK: - Function

    /// 탭바 하단 액세서리 노출 여부.
    ///
    /// 5개 탭이 각자 액세서리를 갖는다(Community 는 생성 화면이 아직 없어 비활성 자리표시).
    /// 판단은 콘텐츠가 아니라 modifier 에서 한다 — `isEnabled:` 없이 콘텐츠만 비우면 SwiftUI 가
    /// 액세서리 컨테이너를 계속 만들어 빈 유리 캡슐과 하단 safe area inset 이 그대로 남는다.
    private var shouldShowAccessory: Bool {
        let userSession = di.resolve(UserSessionManager.self)

        return RootTabAccessoryView.shouldShow(
            tab: pathStore.selectedTab,
            isAtRoot: pathStore.isAtRoot(pathStore.selectedTab),
            role: userSession.currentRole,
            canToggleAdminMode: userSession.canToggleAdminMode
        )
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
            CommunityFeatureView(
                onNoticeSelected: { detailItem in
                    pathStore.push(
                        NavigationDestination.notice(.detail(detailItem: detailItem)),
                        on: .community
                    )
                }
            )
        case .mypage:
            MyPageFeatureView()
        }
    }

    /// 밀려 있던 딥링크를 열어 준다.
    ///
    /// 커뮤니티 탭으로 옮긴 뒤 채팅방을 push 한다. 비멤버 차단은 채팅방이 첫 로드에서
    /// 판정하므로(`CommunityThreadRoomViewModel.load()`) 여기서 미리 막지 않는다 — 링크
    /// 하나 열자고 App 이 커뮤니티 멤버십 규칙을 알 이유가 없다.
    ///
    /// - Note: 공지 링크(`umc://notice/{id}`)는 딥링크로 들어오지 않는다. 메시지 안의 링크
    ///   카드로만 열리고, 그 경로는 `CommunityFeatureView` 가 맡는다.
    private func consumePendingDeepLink() {
        guard case .thread(let threadId)? = deepLinkStore.take() else { return }

        pathStore.selectedTab = .community
        pathStore.push(
            CommunityDestination.threadRoom(threadId: threadId, title: ""),
            on: .community
        )
    }

    /// 탭별 독립 `NavigationStack` path 바인딩을 `PathStore`에 위임한다.
    private func pathBinding(for tab: NavigationTab) -> Binding<NavigationPath> {
        Binding(
            get: { pathStore[tab] },
            set: { pathStore[tab] = $0 }
        )
    }
}
