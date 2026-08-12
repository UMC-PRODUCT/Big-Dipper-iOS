//
//  RootTabAccessoryView.swift
//  UMCApp
//
//  Created by euijjang97 on 8/12/26.
//

import SwiftUI

import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreNetwork
import CoreRouting
import NoticeDomain
import UMCFoundation

/// 탭바 하단 액세서리 콘텐츠.
///
/// 선택된 탭에 맞는 액션 하나만 고른다. 노출 여부는 `RootTabView` 가
/// `.tabViewBottomAccessory(isEnabled:)` 에서 `shouldShow(tab:isAtRoot:role:canToggleAdminMode:)`
/// 로 판단하므로, 각 탭 뷰는 조건을 다시 보지 않는다.
struct RootTabAccessoryView: View {

    // MARK: - Property

    /// 액세서리는 콘텐츠 트리가 아니라 modifier 로 붙어 환경 전파를 신뢰하기 어렵다.
    /// 탭 셸이 이미 들고 있는 인스턴스를 그대로 넘긴다.
    let pathStore: PathStore

    // MARK: - Gating

    /// 액세서리 노출 조건.
    ///
    /// 스택이 쌓인 하위 화면에서는 루트용 액션이 맥락에 맞지 않아 모든 탭에서 숨긴다.
    /// Notice 는 공지 작성 권한이 없는 역할에서, Activity 는 모드 전환 권한이 없을 때 숨긴다.
    static func shouldShow(
        tab: NavigationTab,
        isAtRoot: Bool,
        role: ManagementTeam,
        canToggleAdminMode: Bool
    ) -> Bool {
        guard isAtRoot else { return false }

        switch tab {
        case .notice:
            return role != .challenger && role != .centralOperatingTeamMember
        case .activity:
            return canToggleAdminMode
        case .home, .community, .mypage:
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        switch pathStore.selectedTab {
        case .home:
            HomeAccessory(pathStore: pathStore)
        case .notice:
            NoticeAccessory(pathStore: pathStore)
        case .activity:
            AdminModeToggle()
        case .community:
            CommunityAccessory()
        case .mypage:
            MyPageAccessory()
        }
    }
}

// MARK: - Accessory Action Button

/// 액세서리 공통 액션 버튼. 캡슐 폭을 가득 채우고 아이콘 + 라벨을 가운데 정렬한다.
fileprivate struct AccessoryActionButton: View {

    // MARK: - Property

    let title: String
    let systemImageName: String
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Spacer()

                Image(systemName: systemImageName)
                    .foregroundStyle(Color.indigo500)

                Text(title)
                    .appFont(.body, weight: .semibold)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color.grey900)
        }
    }
}

// MARK: - Home

/// 홈 탭 액세서리 — 일정 생성 진입점.
fileprivate struct HomeAccessory: View {

    // MARK: - Property

    let pathStore: PathStore

    // MARK: - Body

    var body: some View {
        AccessoryActionButton(title: "일정 생성", systemImageName: "plus.circle.fill") {
            pathStore.push(NavigationDestination.home(.registrationSchedule), on: .home)
        }
    }
}

// MARK: - Notice

/// 공지 탭 액세서리 — 공지글 작성 진입점.
fileprivate struct NoticeAccessory: View {

    // MARK: - Property

    let pathStore: PathStore

    @AppStorage(AppStorageKey.noticeSelectedGisuId) private var noticeSelectedGisuId: String = ""

    /// 공지 리스트가 아직 기수를 확정하지 못한 상태(빈 문자열)는 에디터에 nil 로 넘긴다.
    private var selectedGisuId: String? {
        noticeSelectedGisuId.isEmpty ? nil : noticeSelectedGisuId
    }

    // MARK: - Body

    var body: some View {
        AccessoryActionButton(title: "공지글 작성", systemImageName: "plus.circle.fill") {
            let editor = NavigationDestination.Notice.editor(
                mode: .create,
                selectedGisuId: selectedGisuId
            )
            pathStore.push(NavigationDestination.notice(editor), on: .notice)
        }
    }
}

// MARK: - Activity

/// 운영진 ↔ 챌린저 모드 전환 토글.
///
/// 액세서리는 축소(`inline`)·확장(`expanded`) 두 배치를 오가므로, 확장일 때만 현재 역할
/// 배지와 좌우 여백을 더한다. 배치 값은 액세서리 콘텐츠 안에서만 유효해 별도 뷰로 뒀다.
fileprivate struct AdminModeToggle: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var userSession: UserSessionManager {
        di.resolve(UserSessionManager.self)
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

// MARK: - Community

/// 커뮤니티 탭 액세서리 — 게시글 작성 진입점.
///
/// 스레드/게시글 생성 화면이 UMCApp 에 아직 없어(후속 PR) 자리만 잡아 두고 비활성으로 둔다.
fileprivate struct CommunityAccessory: View {

    // MARK: - Body

    var body: some View {
        AccessoryActionButton(title: "게시글 작성", systemImageName: "plus.circle.fill") {}
            .disabled(true)
    }
}

// MARK: - MyPage

/// 마이페이지 탭 액세서리 — 카카오톡 채널 문의 진입점.
fileprivate struct MyPageAccessory: View {

    // MARK: - Property

    @Environment(ErrorHandler.self) private var errorHandler

    private let kakaoPlusManager: KakaoPlusManager = .init()

    // MARK: - Body

    var body: some View {
        AccessoryActionButton(
            title: "문의하기",
            systemImageName: "bubble.left.and.bubble.right.fill"
        ) {
            kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
        }
    }
}
