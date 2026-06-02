//
//  UmcBottonAccessoryView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/19/26.
//

import SwiftUI

/// 탭별 하단 바텀 액세서리 뷰
///
/// 각 탭(Home, Notice, Activity, Community, MyPage)에 대응하는 액세서리를 분기합니다.
/// NavigationStack에 화면이 쌓여있으면 해당 탭의 액세서리를 숨깁니다.
struct UmcBottonAccessoryView: View {

    // MARK: - Property

    @Binding var tabCase: TabCase
    @Environment(\.di) var di
    @Environment(ErrorHandler.self) var errorHandler

    // MARK: - Body

    var body: some View {
        switch tabCase {
        case .home:
            HomeBottonAccessoryView()
        case .notice:
            NoticeAccessoryView()
        case .activity:
            ActivityAccessoryView()
        case .community:
            CommunityAccessoryView()
        case .mypage:
            MyPageAccessoryView()
        }
    }
}

// MARK: - Home

/// 홈 탭 하단 액세서리 - 일정 생성 버튼
fileprivate struct HomeBottonAccessoryView: View {
    @Environment(\.di) var di

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }
//
    var body: some View {
        Group {
            if pathStore.homePath.isEmpty {
                Button(action: {
                    pathStore.homePath.append(.home(.registrationSchedule))
                }, label: {
                    HStack(spacing: DefaultSpacing.spacing8) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.indigo500)

                        Text("일정 생성")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.grey900)
                })
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Notice

/// 공지 탭 하단 액세서리 - 공지글 작성 버튼
fileprivate struct NoticeAccessoryView: View {
    @Environment(\.di) private var di
    @AppStorage(AppStorageKey.noticeSelectedGisuId) private var noticeSelectedGisuId: Int = 0
    @AppStorage(AppStorageKey.memberRole) private var memberRoleRaw: String = ""

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    /// 중앙 운영 사무국원은 공지 작성 권한이 없어 작성 버튼을 노출하지 않습니다.
    private var canShowCreateButton: Bool {
        let role = ManagementTeam(rawValue: memberRoleRaw)
        return role != .centralOperatingTeamMember && role != .challenger
    }

    /// 에디터에 전달할 기수 ID (0이면 nil로 변환)
    private var selectedGisuId: Int? {
        noticeSelectedGisuId > 0 ? noticeSelectedGisuId : nil
    }

    var body: some View {
        Group {
            if pathStore.noticePath.isEmpty && canShowCreateButton {
                Button(action: {
                    pathStore.noticePath.append(
                        .notice(.editor(mode: .create, selectedGisuId: selectedGisuId))
                    )
                }) {
                    HStack(spacing: DefaultSpacing.spacing8) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.indigo500)
                        
                        Text("공지글 작성")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.grey900)
                }
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Activity

/// 활동 탭 하단 액세서리 - 운영진/챌린저 모드 전환 토글
fileprivate struct ActivityAccessoryView: View {
    @Environment(\.di) private var di
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    private var userSession: UserSessionManager {
        di.resolve(UserSessionManager.self)
    }

    var body: some View {
        if userSession.canToggleAdminMode && pathStore.activityPath.isEmpty {
            adminToggleButton
        } else {
            EmptyView()
        }
    }

    /// 운영진/챌린저 모드 전환 버튼
    private var adminToggleButton: some View {
        Button {
            // withAnimation 으로 감싸면 ActivityView 의 무거운 콘텐츠 교체(출석 체크 ↔ 출석 현황)까지
            // 함께 애니메이션돼 두 화면이 겹쳐 보이는 잔상·경계선이 생긴다. 모드 전환은 즉시 처리한다.
            userSession.toggleAdminMode()
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: userSession.isAdminModeEnabled
                    ? "gearshape.fill" : "gearshape")
                    .foregroundStyle(userSession.isAdminModeEnabled ? .indigo500 : .grey600)

                // 축소/확장 상태 모두 텍스트 표시
                Text(userSession.isAdminModeEnabled ? "운영진 모드" : "챌린저 모드")
                    .appFont(placement == .expanded ? .subheadline : .subheadline)
                    .foregroundStyle(.black)

                if placement == .expanded {
                    Spacer()

                    // 현재 역할 배지
                    Text(userSession.currentRole.displayName)
                        .appFont(.subheadline, color: .indigo500)
                }
            }
            .padding(.horizontal, placement == .expanded ? DefaultConstant.defaultSafeHorizon : 0)
        }
    }
}

// MARK: - Community

/// 커뮤니티 탭 하단 액세서리 - 게시글 작성 버튼
fileprivate struct CommunityAccessoryView: View {
    @Environment(\.di) private var di

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    var body: some View {
        Group {
            if pathStore.communityPath.isEmpty {
                Button(action: {
                    pathStore.communityPath.append(.community(.post()))
                }) {
                    HStack(spacing: DefaultSpacing.spacing8) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.indigo500)

                        Text("게시글 작성")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.grey900)
                }
            } else {
                EmptyView()
            }
        }
    }
}
// MARK: - MyPage

/// 마이페이지 탭 하단 액세서리 - 문의하기 버튼
fileprivate struct MyPageAccessoryView: View {
    @Environment(ErrorHandler.self) private var errorHandler

    private let kakaoPlusManager: KakaoPlusManager = .init()

    var body: some View {
        Button(action: {
            kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
        }) {
            HStack(spacing: DefaultSpacing.spacing8) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.indigo500)

                Text("문의하기")
                    .fontWeight(.semibold)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.grey900)
        }
    }
}
