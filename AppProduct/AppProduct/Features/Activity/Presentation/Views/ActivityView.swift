//
//  ActivityView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/23/26.
//

import SwiftUI

/// Activity Feature 메인 화면
///
/// Challenger/Admin 모드에 따라 다른 섹션을 표시합니다.
struct ActivityView: View {
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) var errorHandler
    @State private var selectedSection: ActivitySection?
    @State private var viewModel: ActivityViewModel?

    // MARK: - Computed Property

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    private var userSession: UserSessionManager {
        di.resolve(UserSessionManager.self)
    }

    /// Provider를 통해 UseCase 접근
    private var activityProvider: ActivityUseCaseProviding {
        di.resolve(ActivityUseCaseProviding.self)
    }

    /// 현재 모드에서 사용 가능한 섹션 목록
    private var availableSections: [ActivitySection] {
        ActivitySection.sections(for: userSession.currentActivityMode)
    }

    /// 현재 선택된 섹션 (선택 없으면 기본 섹션)
    private var currentSection: ActivitySection {
        selectedSection ?? ActivitySection.defaultSection(for: userSession.currentActivityMode)
    }

    private var sectionBinding: Binding<ActivitySection> {
        Binding(
            get: { currentSection },
            set: { selectedSection = $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: Binding(
            get: { pathStore.activityPath },
            set: { pathStore.activityPath = $0 }
        )) {
            sectionContent(
                for: currentSection,
                mode: userSession.currentActivityMode
            )
            .navigationTitle(currentSection.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.ToolBarCenterMenu(
                    items: availableSections,
                    selection: sectionBinding,
                    itemLabel: { $0.rawValue },
                    itemIcon: { $0.icon }
                )
            }
            .umcDefaultBackground()
            .task {
                // ViewModel 초기화 및 데이터 로드(Computed Property를 위해 init 대신 task에서 초기화)
                if viewModel == nil {
                    viewModel = ActivityViewModel(
                        fetchSessionsUseCase: activityProvider.fetchSessionsUseCase,
                        fetchUserIdUseCase: activityProvider.fetchUserIdUseCase,
                        classifyScheduleUseCase: activityProvider.classifyScheduleUseCase
                    )
                }
                await viewModel?.loadInitialData()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                NavigationRoutingView(destination: destination)
            }
            .onChange(of: userSession.currentActivityMode) { oldMode, newMode in
                let previousSection = selectedSection ?? ActivitySection.defaultSection(for: oldMode)
                selectedSection = previousSection.mapped(to: newMode)
            }
        }
    }

    // MARK: - View Component

    /// 섹션에 해당하는 뷰 반환
    @ViewBuilder
    private func sectionContent(
        for section: ActivitySection,
        mode: ActivityMode
    ) -> some View {
        switch (mode, section) {
        case (.challenger, .attendanceCheck):
            attendanceContent
        case (.challenger, .studyActivity):
            ChallengerStudyView(
                container: di, errorHandler: errorHandler)
        case (.challenger, .members):
            ChallengerMemberListView(
                container: di, errorHandler: errorHandler, userSessionManager: userSession)
        case (.admin, .attendanceManage):
            operatorAttendanceContent
        case (.admin, .studyManage):
            OperatorStudyManagementView(container: di, errorHandler: errorHandler)
        case (.admin, .memberManage):
            OperatorMemberManagementView(container: di, errorHandler: errorHandler, userSessionManager: userSession)
        default:
            EmptyView()
        }
    }

    private var operatorAttendanceContent: some View {
        AttendanceListView(
            container: di,
            errorHandler: errorHandler
        )
    }

    /// 출석 확인 섹션 (ViewModel 상태에 따라 표시)
    @ViewBuilder
    private var attendanceContent: some View {
        if let vm = viewModel {
            switch vm.sessionsState {
            case .idle, .loading:
                ProgressView("세션 로딩 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let sessions):
                ChallengerAttendanceSessionView(
                    container: di,
                    errorHandler: errorHandler,
                    sessions: sessions,
                    userId: vm.userId ?? UserID(value: ""),
                    categoryFor: vm.category(for:)
                )
            case .failed(let error):
                RetryContentUnavailableView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage,
                    isRetrying: false
                ) {
                    await vm.fetchSessions()
                }
            }
        } else {
            ProgressView()
        }
    }
}
