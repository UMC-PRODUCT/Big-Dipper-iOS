//
//  ActivityView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreRouting
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// Activity 탭 루트 화면
///
/// 로그인 역할이 결정하는 모드(``CoreDomain/ActivityMode``)와 사용자가 고른 섹션
/// (``ActivitySection``)의 조합으로 자식 화면을 고른다. 섹션 전환은 상단 타이틀 메뉴에서 하고,
/// 모드가 바뀌면 보고 있던 자리에 대응하는 섹션으로 옮겨 같은 성격의 화면을 유지한다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유하고,
///   자식 화면들도 같은 규약으로 이식돼 있어 여기서 스택을 만들면 중첩된다.
struct ActivityView: View {

    // MARK: - Property

    /// 탭 스택의 공유 경로. 자식 화면이 요청한 push 를 이 저장소로 넘긴다.
    @Environment(PathStore.self) private var pathStore

    @State private var viewModel: ActivityViewModel
    @State private var selectedSection: ActivitySection?

    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let userSession: UserSessionManager

    // MARK: - Init

    /// - Parameters:
    ///   - container: 자식 화면이 UseCase·세션을 resolve 할 DI 컨테이너
    ///   - errorHandler: 흐름 중단형 전역 에러 처리기
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container 로 생성)
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        viewModel: ActivityViewModel? = nil
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.userSession = container.resolve(UserSessionManager.self)
        _viewModel = State(
            initialValue: viewModel ?? ActivityViewModel(
                challengerAttendanceUseCase: container.resolve(
                    ChallengerAttendanceUseCaseProtocol.self
                ),
                fetchUserIdUseCase: container.resolve(FetchUserIdUseCaseProtocol.self),
                classifyScheduleUseCase: container.resolve(ClassifyScheduleUseCaseProtocol.self)
            )
        )
    }

    // MARK: - Computed Property

    private var mode: ActivityMode {
        userSession.currentActivityMode
    }

    /// 현재 모드에서 고를 수 있는 섹션 목록
    private var availableSections: [ActivitySection] {
        ActivitySection.sections(for: mode)
    }

    /// 사용자가 고른 섹션 (고르기 전이면 모드의 기본 섹션)
    private var currentSection: ActivitySection {
        selectedSection ?? ActivitySection.defaultSection(for: mode)
    }

    private var sectionBinding: Binding<ActivitySection> {
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
                    itemLabel: \.title,
                    itemIcon: \.icon
                )
                #if DEBUG
                debugModeToggleItem
                #endif
            }
            .task {
                await viewModel.load()
            }
            .onChange(of: mode) { oldMode, newMode in
                let previous = selectedSection ?? ActivitySection.defaultSection(for: oldMode)
                selectedSection = previous.mapped(to: newMode)
            }
    }

    // MARK: - View Component

    /// 모드×섹션 조합에 해당하는 자식 화면
    ///
    /// 두 축을 함께 스위치해 "운영진 모드인데 챌린저 섹션" 같은 성립하지 않는 조합이
    /// 남지 않게 한다. 섹션 목록 자체가 모드로 걸러지므로 `default` 는 도달하지 않지만,
    /// 열거형이 늘어날 때 컴파일을 막지 않도록 빈 화면으로 닫아 둔다.
    @ViewBuilder
    private var sectionContent: some View {
        switch (mode, currentSection) {
        case (.challenger, .attendanceCheck):
            attendanceContent

        case (.challenger, .studyActivity):
            ChallengerStudyView(
                viewModel: ChallengerStudyViewModel(
                    fetchCurriculumOverviewUseCase: container.resolve(
                        FetchCurriculumOverviewUseCaseProtocol.self
                    )
                )
            )

        case (.challenger, .members):
            ChallengerMemberListView(container: container, errorHandler: errorHandler)

        case (.admin, .attendanceManage):
            OperatorAttendanceView(
                errorHandler: errorHandler,
                useCase: container.resolve(OperatorAttendanceUseCaseProtocol.self)
            )

        case (.admin, .studyManage):
            OperatorStudyManagementView(
                viewModel: OperatorStudyManagementViewModel(
                    errorHandler: errorHandler,
                    useCase: container.resolve(OperatorStudyManagementUseCaseProtocol.self)
                ),
                userSession: userSession,
                onRegisterSchedule: { group in
                    // 식별자는 서버 응답 그대로 `String` 이라 변환 단계가 없다.
                    pathStore.push(
                        ActivityDestination.studyScheduleRegistration(
                            studyName: group.name,
                            studyGroupId: group.serverID
                        ),
                        on: .activity
                    )
                }
            )

        case (.admin, .memberManage):
            OperatorMemberManagementView(container: container, errorHandler: errorHandler)

        default:
            EmptyView()
        }
    }

    /// 출석 체크 섹션 — 세션 목록 상태에 따라 분기
    @ViewBuilder
    private var attendanceContent: some View {
        switch viewModel.sessionsState {
        case .idle, .loading:
            loadingView

        case .loaded(let sessions):
            // 출석 주체를 모른 채로는 출석 기록을 남길 수 없다. 레거시는 빈 식별자로
            // 폴백했지만, 그러면 로그인 세션이 끊긴 상태가 조용히 흡수돼 잘못된 주체로
            // 기록이 남는다. 식별자가 없으면 재조회를 안내한다.
            if let userId = viewModel.userId {
                ChallengerAttendanceSessionView(
                    container: container,
                    errorHandler: errorHandler,
                    sessions: sessions,
                    userId: userId
                )
            } else {
                missingUserIdView
            }

        case .failed(let error):
            RetryContentUnavailableView(
                title: "불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.fetchSessions()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ProgressView()

            Text("세션 불러오는 중...")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var missingUserIdView: some View {
        RetryContentUnavailableView(
            title: "사용자 정보를 확인하지 못했어요",
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: "출석을 기록하려면 로그인 정보가 필요해요.\n다시 시도해도 같으면 재로그인해 주세요.",
            isRetrying: false
        ) {
            await viewModel.fetchUserId()
        }
    }

    #if DEBUG
    /// 챌린저 ↔ 운영진 모드 전환 (DEBUG 전용)
    ///
    /// 운영 빌드의 모드 토글은 탭바 하단 액세서리가 담당하며 아직 이식 전이다. 그때까지
    /// 운영진 섹션이 도달 불가능해지지 않도록 DEBUG 빌드에만 임시 진입점을 둔다.
    /// // TODO: 탭바 액세서리 모드 토글 결선 후 제거 - [26.08.03] 이재원
    private var debugModeToggleItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                userSession.toggleAdminMode()
            } label: {
                Label(
                    mode == .admin ? "운영진" : "챌린저",
                    systemImage: mode == .admin
                        ? "person.badge.shield.checkmark"
                        : "person"
                )
            }
        }
    }
    #endif
}
