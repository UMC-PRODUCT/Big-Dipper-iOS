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
import CoreUIComponents
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

// MARK: - Harness

/// 이식 완료된 Activity 화면을 서버·로그인 없이 확인하기 위한 DEBUG 전용 하네스
///
/// 레거시 `AppProduct`의 `ActivityView`와 같은 구성을 따른다 — 탭 진입 시 기본 섹션(출석)을
/// 바로 보여주고, 상단 타이틀 메뉴로 섹션을 전환한다. 챌린저/운영진 모드 전환은 레거시가
/// 하단 액세서리에서 처리하지만, 하네스는 그 배선이 없어 툴바 버튼으로 대신한다.
///
/// 각 화면은 스텁 UseCase(`PreviewSupport`)로 조립한 ViewModel을 주입받아 네트워크를 타지
/// 않는다. 상위 `RootTabView`가 탭별 `NavigationStack`을 제공하므로 여기서 스택을 만들지 않는다.
/// // TODO: Activity 라우터·탭바 실연결 후 실제 배선으로 교체 - [26.08.03] 이재원
@MainActor
private struct DebugActivityHarnessView: View {

    // MARK: - Property

    /// 하네스가 소유하는 세션. 운영진 권한 계정으로 두어 모드 전환을 확인할 수 있다.
    @State private var userSession: UserSessionManager
    @State private var errorHandler = ErrorHandler()
    @State private var selectedSection: DebugActivitySection?
    @State private var showsStudyGroupCreate = false

    // MARK: - Init

    /// 운영진 모드로 시작한다.
    ///
    /// 레거시 기본 모드는 챌린저지만, 그 기본 섹션인 출석 체크 화면
    /// (`ChallengerAttendanceSessionView`)이 아직 이식되지 않아 진입 화면이 안내 문구가 된다.
    /// 하네스의 목적은 이식된 화면 확인이므로, 실제로 볼 수 있는 출석 화면이 바로 뜨도록
    /// 운영진 모드를 초기값으로 둔다. 툴바 버튼으로 챌린저 모드로 전환할 수 있다.
    init() {
        let session = previewCreateCapableSession()
        session.toggleAdminMode()
        _userSession = State(wrappedValue: session)
    }

    // MARK: - Computed Property

    private var mode: ActivityMode {
        userSession.currentActivityMode
    }

    private var availableSections: [DebugActivitySection] {
        DebugActivitySection.sections(for: mode)
    }

    private var currentSection: DebugActivitySection {
        selectedSection ?? DebugActivitySection.defaultSection(for: mode)
    }

    private var sectionBinding: Binding<DebugActivitySection> {
        Binding(
            get: { currentSection },
            set: { selectedSection = $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        sectionContent
            .navigationTitle(currentSection.title)
            .navigationBarTitleDisplayMode(.inline)
            .umcDefaultBackground()
            .toolbar {
                ToolBarCollection.ToolBarCenterMenu(
                    items: availableSections,
                    selection: sectionBinding,
                    itemLabel: { $0.title },
                    itemIcon: { $0.icon }
                )
                modeToggleItem
                studyGroupCreateItem
            }
            .navigationDestination(isPresented: $showsStudyGroupCreate) {
                OperatorStudyGroupCreateView(
                    viewModel: previewOperatorStudyManagementViewModel()
                )
            }
            // 레거시 `ActivityView`와 동일하게, 모드가 바뀌면 보고 있던 섹션을
            // 대응 섹션으로 옮겨 같은 성격의 화면을 유지한다.
            .onChange(of: mode) { oldMode, newMode in
                let previous = selectedSection
                    ?? DebugActivitySection.defaultSection(for: oldMode)
                selectedSection = previous.mapped(to: newMode)
            }
    }

    // MARK: - View Components

    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .attendanceCheck:
            // `ChallengerAttendanceSessionView`는 아직 이식되지 않았다.
            notPortedGuide(
                title: "출석 체크",
                description: "챌린저 출석 화면은 아직 이식되지 않았습니다.\n운영진 모드로 전환하면 출석 관리 화면을 확인할 수 있습니다."
            )

        case .studyActivity:
            ChallengerStudyView(viewModel: MissionPreviewData.makeViewModel())

        case .members:
            ChallengerMemberListView(
                container: DIContainer(),
                errorHandler: errorHandler,
                viewModel: previewMemberListViewModel(
                    errorHandler: errorHandler,
                    session: previewChallengerSession()
                )
            )

        case .attendanceManage:
            OperatorAttendanceView(
                errorHandler: errorHandler,
                useCase: PreviewOperatorAttendanceUseCase()
            )

        case .studyManage:
            OperatorStudyManagementView(
                viewModel: previewOperatorStudyManagementViewModel(),
                userSession: userSession
            )

        case .memberManage:
            OperatorMemberManagementView(
                container: DIContainer(),
                errorHandler: errorHandler,
                viewModel: previewMemberListViewModel(
                    errorHandler: errorHandler,
                    session: userSession
                )
            )
        }
    }

    /// 챌린저 ↔ 운영진 모드 전환 버튼 (레거시의 하단 액세서리 토글 대체)
    private var modeToggleItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                userSession.toggleAdminMode()
            } label: {
                Label(
                    mode == .admin ? "운영진" : "챌린저",
                    systemImage: mode == .admin ? "person.badge.shield.checkmark" : "person"
                )
            }
        }
    }

    /// 스터디 그룹 생성 폼 진입 버튼
    ///
    /// 운영 화면에서는 멘토·스터디원 선택 이식 전까지 진입점이 게이팅("준비 중")돼 있어,
    /// 하네스에서만 직접 열 수 있게 둔다.
    @ToolbarContentBuilder
    private var studyGroupCreateItem: some ToolbarContent {
        if currentSection == .studyManage {
            ToolbarItem(placement: .topBarTrailing) {
                Button("생성 폼") {
                    showsStudyGroupCreate = true
                }
            }
        }
    }

    private func notPortedGuide(title: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            Text(description)
        }
    }
}

// MARK: - Section Catalog

/// 하네스가 노출하는 Activity 섹션
///
/// 레거시 `ActivitySection`과 같은 구성이다. 프로덕션 `ActivitySection`은 Activity 탭 루트
/// 이식 이슈에서 별도로 들어오므로, 하네스는 DEBUG 전용 사본을 쓴다.
private enum DebugActivitySection: String, Identifiable, Hashable, CaseIterable {
    case attendanceCheck
    case studyActivity
    case members
    case attendanceManage
    case studyManage
    case memberManage

    var id: Self { self }

    var title: String {
        switch self {
        case .attendanceCheck: "출석 체크"
        case .studyActivity: "스터디/활동"
        case .members: "구성원"
        case .attendanceManage: "출석 관리"
        case .studyManage: "스터디 관리"
        case .memberManage: "멤버 관리"
        }
    }

    var icon: String {
        switch self {
        case .attendanceCheck, .attendanceManage: "checkmark.circle"
        case .studyActivity, .studyManage: "book.pages"
        case .members, .memberManage: "person.3"
        }
    }

    static func sections(for mode: ActivityMode) -> [DebugActivitySection] {
        switch mode {
        case .challenger: [.attendanceCheck, .studyActivity, .members]
        case .admin: [.attendanceManage, .studyManage, .memberManage]
        }
    }

    static func defaultSection(for mode: ActivityMode) -> DebugActivitySection {
        switch mode {
        case .challenger: .attendanceCheck
        case .admin: .attendanceManage
        }
    }

    /// 모드 전환 시 같은 성격의 섹션으로 매핑한다.
    func mapped(to mode: ActivityMode) -> DebugActivitySection {
        switch mode {
        case .challenger:
            switch self {
            case .attendanceCheck, .attendanceManage: .attendanceCheck
            case .studyActivity, .studyManage: .studyActivity
            case .members, .memberManage: .members
            }
        case .admin:
            switch self {
            case .attendanceCheck, .attendanceManage: .attendanceManage
            case .studyActivity, .studyManage: .studyManage
            case .members, .memberManage: .memberManage
            }
        }
    }
}
#endif
