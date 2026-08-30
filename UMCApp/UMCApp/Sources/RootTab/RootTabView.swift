//
//  RootTabView.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import SwiftUI

import ActivityDomain
import ActivityPresentation
import BusinessCardDomain
import BusinessCardPresentation
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

    /// 딥링크로 받은 명함 링크. 수신 모디파이어가 처리 후 비운다.
    @State private var pendingCardLink: CardLink?

    /// 다른 탭이 요청한 Activity 진입 지점. Activity 탭 루트가 처리 후 비운다.
    @State private var pendingActivityEntry: ActivityEntry?

    /// 출석 푸시가 지목한 일정 식별자. 활동 탭 말단이 해당 세션을 펼친 뒤 비운다.
    @State private var focusedAttendanceScheduleId: String?

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
        // 명함 링크는 탭을 옮기는 것으로 끝나지 않는다 — 서버 조회·저장·완료 화면까지가
        // 한 동작이라 탭 셸 바깥(모달)에 붙인다.
        .businessCardLinkReceiver(link: $pendingCardLink, container: di)
        // 앱이 켜져 있는 동안 도착한 링크와, 로그인 화면에 머무는 사이 밀려 있던 링크를
        // 같은 함수로 받는다. 후자는 이 뷰가 처음 뜨는 시점에 한 번 꺼내면 된다.
        .task { consumePendingDeepLink() }
        .onChange(of: deepLinkStore.pending) { _, _ in consumePendingDeepLink() }
        #if DEBUG
        // 실행 인자 `-bcHarness`로 명함 검증 화면에 바로 진입한다.
        // (탭 조작 없이 시뮬레이터에서 검증을 재현하기 위한 경로 — 제품 동작 아님)
        .task { openBusinessCardHarnessIfRequested() }
        #endif
    }

    #if DEBUG
    /// `-bcHarness` 실행 인자가 있으면 마이페이지 탭의 명함 검증 화면을 연다.
    private func openBusinessCardHarnessIfRequested() {
        guard CommandLine.arguments.contains("-bcHarness") else { return }
        pathStore.selectedTab = .mypage
        pathStore.push(BusinessCardDebugDestination.harness, on: .mypage)
    }
    #endif

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
                .navigationDestination(for: BusinessCardDestination.self) { destination in
                    BusinessCardRoutingView(destination: destination, container: di)
                }
                #if DEBUG
                .navigationDestination(for: BusinessCardDebugDestination.self) { _ in
                    BusinessCardDebugView(container: di)
                }
                #endif
        }
    }

    /// 탭별 루트 화면. 5개 탭 모두 실연결된 Feature 화면을 표시한다.
    ///
    /// Activity와 Community는 자기 목적지(`ActivityDestination`/`CommunityDestination`) 등록까지
    /// 각 Feature 루트가 맡으므로, App은 그 화면 구성을 알지 못한 채 진입점만 걸어 준다. 반면
    /// Home/Notice는 목적지가 App 소유(`NavigationDestination`)라 push 클로저를 여기서 넘긴다.
    /// MyPage는 명함 진입만 중립 enum(`BusinessCardEntry`)으로 받아 App 셸이
    /// `BusinessCardDestination`으로 번역해 push한다.
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
            ActivityFeatureView(
                pendingEntry: $pendingActivityEntry,
                focusedScheduleId: $focusedAttendanceScheduleId
            )
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
            MyPageFeatureView(
                onOpenBusinessCard: { entry in
                    pathStore.push(businessCardDestination(for: entry), on: .mypage)
                },
                onOpenStudy: {
                    pendingActivityEntry = Self.enterActivityStudy(pathStore: pathStore)
                }
            )
        }
    }

    /// 마이페이지 「나의 스터디」 → Activity 탭의 스터디 섹션(MP-F10).
    ///
    /// 탭만 바꾸면 두 군데가 어긋난다.
    /// 1. `PathStore` 는 탭별 스택을 보존하므로 Activity 에 남아 있던 상세 화면이 복원된다.
    ///    → 그 탭의 경로를 루트로 되돌린다(선례: 커뮤니티 스레드 이탈 시 `pathStore[.community]`).
    /// 2. Activity 루트가 마지막에 고른 섹션을 들고 있어 기본값인 출석 화면이 뜬다.
    ///    → 섹션은 ``ActivityEntry`` 요청으로 넘긴다.
    ///
    /// 어느 섹션이 「스터디」인지(모드별 `.studyActivity`/`.studyManage`)는 Activity 모듈이
    /// 정한다 — App 은 "스터디로 가고 싶다"만 말한다. Feature 끼리 직접 목적지를 넘기지 않고
    /// App 셸이 중개하는 규약은 ``businessCardDestination(for:)`` 과 같다.
    ///
    /// 뷰 렌더링 없이 전이를 검증하려고 `static` 으로 뽑았다
    /// (선례: `RootTabAccessoryView.shouldShow`, `MyPageView.retryCardAndProfile`).
    static func enterActivityStudy(pathStore: PathStore) -> ActivityEntry {
        pathStore[.activity] = NavigationPath()
        pathStore.selectedTab = .activity

        return .study
    }

    /// 마이페이지의 중립 진입 요청을 명함 목적지로 번역한다.
    /// (Feature끼리 직접 목적지를 넘기지 않는 이 레포 규약 — App 셸이 중개한다.)
    private func businessCardDestination(for entry: BusinessCardEntry) -> BusinessCardDestination {
        switch entry {
        case .receivedCards: .receivedCards
        case .cardQR: .cardQR
        case .exchange: .exchange
        }
    }

    /// 밀려 있던 딥링크를 열어 준다.
    ///
    /// 커뮤니티 탭으로 옮긴 뒤 채팅방을 push 한다. 비멤버 차단은 채팅방이 첫 로드에서
    /// 판정하므로(`CommunityThreadRoomViewModel.load()`) 여기서 미리 막지 않는다 — 링크
    /// 하나 열자고 App 이 커뮤니티 멤버십 규칙을 알 이유가 없다.
    ///
    /// 출석 링크는 push 없이 활동 탭으로 옮기고 해당 세션 카드를 펼치는 것으로 끝난다 —
    /// 출석 화면은 탭 루트라 밀어 넣을 목적지가 따로 없다.
    ///
    /// - Note: 공지 링크(`umc://notice/{id}`)는 딥링크로 들어오지 않는다. 메시지 안의 링크
    ///   카드로만 열리고, 그 경로는 `CommunityFeatureView` 가 맡는다.
    private func consumePendingDeepLink() {
        switch deepLinkStore.take() {
        case .message(.thread(let threadId)):
            pathStore.selectedTab = .community
            pathStore.push(
                CommunityDestination.threadRoom(threadId: threadId, title: ""),
                on: .community
            )

        case .card(let link):
            // 저장 결과는 마이페이지(명함첩이 사는 탭)에서 알리는 게 맥락이 맞다.
            // 조회·저장·완료 화면은 `businessCardLinkReceiver` 가 맡는다.
            pathStore.selectedTab = .mypage
            pendingCardLink = link

        case .attendance(let link):
            pathStore.selectedTab = .activity
            focusedAttendanceScheduleId = link.scheduleId

        case .message(.notice), .none:
            return
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
