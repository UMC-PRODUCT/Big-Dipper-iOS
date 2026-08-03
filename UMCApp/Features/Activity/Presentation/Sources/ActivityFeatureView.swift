//
//  ActivityFeatureView.swift
//  ActivityPresentation
//
//  Created by euijjang97 on 3/6/26.
//

import SwiftUI
#if DEBUG
import CoreDesignSystem
import CoreDI
import CoreDomain
import UMCFoundation
#endif

public struct ActivityFeatureView: View {
    public init() {}

    public var body: some View {
        #if DEBUG
        DebugActivityHarnessView()
        #else
        Text("Activity Feature")
        #endif
    }
}

#if DEBUG

// MARK: - Harness Entry

/// 이식 완료된 Activity 화면을 서버·로그인 없이 확인하기 위한 DEBUG 전용 하네스
///
/// Activity 라우터·탭바 실연결(#997) 전까지 쓰는 임시 진입점이다. 각 화면은 스텁
/// UseCase(`PreviewSupport`)로 조립한 ViewModel을 주입받으므로 네트워크를 타지 않는다.
/// 상위 `RootTabView`가 탭별 `NavigationStack`을 제공하므로 여기서 스택을 만들지 않는다.
/// // TODO: Activity 라우터·탭바 실연결 후 실제 배선으로 교체 - [26.08.03] 이재원
private struct DebugActivityHarnessView: View {

    // MARK: - Body

    var body: some View {
        List {
            Section {
                ForEach(DebugActivityScreen.allCases) { screen in
                    // 상위 `RootTabView`의 `NavigationStack`이 `[NavigationDestination]`
                    // 타입 경로를 쓰므로, 다른 타입의 value 링크는 무시된다. 하네스는
                    // 앱 라우팅에 끼어들지 않도록 목적지 뷰를 직접 들고 있는 링크를 쓴다.
                    NavigationLink {
                        DebugActivityScreenView(screen: screen)
                    } label: {
                        row(for: screen)
                    }
                }
            } header: {
                Text("이식 완료 화면")
            } footer: {
                Text("서버·로그인 없이 스텁 데이터로 렌더됩니다. 실제 배선은 Activity 탭 연결 이슈에서 교체됩니다.")
            }
        }
        .navigationTitle("Activity 하네스")
    }

    // MARK: - View Components

    private func row(for screen: DebugActivityScreen) -> some View {
        Label {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(screen.title)
                    .appFont(.callout)

                Text(screen.detail)
                    .appFont(.footnote, color: .grey500)
            }
        } icon: {
            Image(systemName: screen.systemImageName)
                .foregroundStyle(Color.indigo500)
        }
    }
}

// MARK: - Screen Catalog

/// 하네스가 노출하는 화면 목록
private enum DebugActivityScreen: String, CaseIterable, Identifiable, Hashable {
    case challengerStudy
    case challengerMemberList
    case operatorAttendance
    case operatorMemberManagement
    case operatorStudyManagement
    case operatorStudyGroupCreate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .challengerStudy: "챌린저 — 스터디(커리큘럼)"
        case .challengerMemberList: "챌린저 — 구성원 목록"
        case .operatorAttendance: "운영진 — 출석 관리"
        case .operatorMemberManagement: "운영진 — 멤버 관리"
        case .operatorStudyManagement: "운영진 — 스터디 관리"
        case .operatorStudyGroupCreate: "운영진 — 스터디 그룹 생성 폼"
        }
    }

    var detail: String {
        switch self {
        case .challengerStudy: "진행률 게이지 + 주차별 미션 카드"
        case .challengerMemberList: "파트별 그룹핑 · 검색 · 멤버 상세 시트"
        case .operatorAttendance: "일정 목록 → 상세 · 승인 대기 결정 · 위치 변경"
        case .operatorMemberManagement: "멤버 목록 + 상벌점 부여/삭제 시트"
        case .operatorStudyManagement: "스터디 그룹 목록 · 멘토/스터디원 관리"
        case .operatorStudyGroupCreate: "그룹 생성 폼 (운영 화면에서는 게이팅됨)"
        }
    }

    var systemImageName: String {
        switch self {
        case .challengerStudy: "book.closed"
        case .challengerMemberList: "person.2"
        case .operatorAttendance: "checkmark.circle"
        case .operatorMemberManagement: "person.badge.shield.checkmark"
        case .operatorStudyManagement: "rectangle.grid.2x2"
        case .operatorStudyGroupCreate: "plus.rectangle.on.folder"
        }
    }
}

// MARK: - Screen Host

/// 선택한 화면을 스텁 의존성으로 조립해 표시한다.
///
/// 화면마다 필요한 ViewModel·세션이 달라, 조립은 각 `case`에서 직접 수행한다.
/// `ErrorHandler`는 하네스가 소유해 화면 전환 간에도 알럿 상태가 유지되게 한다.
private struct DebugActivityScreenView: View {

    // MARK: - Property

    let screen: DebugActivityScreen

    @State private var errorHandler = ErrorHandler()

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle(screen.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - View Components

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .challengerStudy:
            ChallengerStudyView(viewModel: MissionPreviewData.makeViewModel())

        case .challengerMemberList:
            ChallengerMemberListView(
                container: DIContainer(),
                errorHandler: errorHandler,
                viewModel: previewMemberListViewModel(
                    errorHandler: errorHandler,
                    session: previewChallengerSession()
                )
            )

        case .operatorAttendance:
            OperatorAttendanceView(
                errorHandler: errorHandler,
                useCase: PreviewOperatorAttendanceUseCase()
            )

        case .operatorMemberManagement:
            OperatorMemberManagementView(
                container: DIContainer(),
                errorHandler: errorHandler,
                viewModel: previewMemberListViewModel(
                    errorHandler: errorHandler,
                    session: previewCreateCapableSession()
                )
            )

        case .operatorStudyManagement:
            OperatorStudyManagementView(
                viewModel: previewOperatorStudyManagementViewModel(),
                userSession: previewCreateCapableSession()
            )

        case .operatorStudyGroupCreate:
            OperatorStudyGroupCreateView(
                viewModel: previewOperatorStudyManagementViewModel()
            )
        }
    }
}
#endif
